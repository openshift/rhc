require 'base64'
require 'rhc/json'
require 'rhc/rest/base'
require 'rhc/helpers'
require 'uri'

RestClient.proxy = URI.parse(ENV['http_proxy']).to_s if ENV['http_proxy']

module RHC
  module Rest
    class Client < Base

      # Keep the list of supported API versions here
      # The list may not necessarily be sorted; we will select the last
      # matching one supported by the server.
      # See #api_version_negotiated
      CLIENT_API_VERSIONS = [1.1, 1.2, 1.3]

      def initialize(*args)
        options = args[0].is_a?(Hash) && args[0] || {}
        @end_point, @username, @password, @debug, @preferred_api_versions =
          if options.empty?
            args
          else
            [options[:url], options[:username], options[:password], options[:debug], options[:preferred_api_versions]]
          end

        @debug ||= false
        @auth = options[:auth]
        headers.merge!(options[:headers]) if options[:headers]
        add_headers(headers) #TODO remove me

        @preferred_api_versions ||= CLIENT_API_VERSIONS

        debug "Connecting to #{@end_point}"
      end

      def api
        @api ||= RHC::Rest::Api.new(self, @preferred_api_versions)
      end

      def api_version_negotiated
        api.api_version_negotiated
      end

      def add_domain(id)
        debug "Adding domain #{id}"
        @domains = nil
        api.rest_method "ADD_DOMAIN", :id => id
      end

      def domains
        debug "Getting all domains"
        @domains ||= api.rest_method "LIST_DOMAINS"
      end

      def cartridges
        debug "Getting all cartridges"
        api.rest_method("LIST_CARTRIDGES")
      end

      def user
        debug "Getting user info"
        api.rest_method "GET_USER"
      end

      def sshkeys
        debug "Finding all keys for #{user.login}"
        user.keys
      end

      def add_key(name, key, content)
        debug "Adding key #{key} for #{user.login}"
        user.add_key name, key, content
      end

      def delete_key(name)
        debug "Deleting key '#{name}'"
        key = find_key(name)
        key.destroy
      end

      #Find Domain by namesapce
      def find_domain(id)
        debug "Finding domain #{id}"
        domains.each { |domain| return domain if domain.id == id }

        raise RHC::DomainNotFoundException.new("Domain #{id} does not exist")
      end

      #Find Cartridge by name or regex
      def find_cartridges(name)
        debug "Finding cartridge #{name}"
        if name.is_a?(Hash)
          regex = name[:regex]
          type = name[:type]
          name = name[:name]
        end

        filtered = Array.new
        cartridges.each do |cart|
          if regex
            filtered.push(cart) if cart.name.match(regex) and (type.nil? or cart.type == type)
          else
            filtered.push(cart) if (name.nil? or cart.name == name) and (type.nil? or cart.type == type)
          end
        end
        return filtered
      end

      #find Key by name
      def find_key(name)
        debug "Finding key #{name}"
        user.find_key(name) or raise RHC::KeyNotFoundException.new("Key #{name} does not exist")
      end

      def sshkeys
        logger.debug "Finding all keys for #{user.login}" if @mydebug
        user.keys
      end

      def add_key(name, key, content)
        logger.debug "Adding key #{key} for #{user.login}" if @mydebug
        user.add_key name, key, content
      end

      def delete_key(name)
        logger.debug "Deleting key '#{name}'" if @mydebug
        key = find_key(name)
        key.destroy
      end

      def logout
        #TODO logout
        debug "Logout/Close client"
      end
      alias :close :logout

      def debug?
        @debug
      end

      def logger
        Logger.new(STDOUT)
      end

      def request(options, &block)
        tried = 0
        begin
          request = options.is_a?(RestClient::Request) && options || new_request(options)
          debug "Request: #{request.inspect}" if debug?
          begin
            response = request.execute
          ensure
            debug "Response: #{response.inspect}" rescue nil if debug?
          end

          if block_given?
            yield response
          else
            parse_response(response) unless response.nil? or response.code == 204
          end
        rescue RestClient::RequestTimeout => e
          raise TimeoutException.new(
            "Connection to server timed out. "\
            "It is possible the operation finished without being able "\
            "to report success. Use 'rhc domain show' or 'rhc app show' "\
            "to see the status of your applications.")
        rescue RestClient::ServerBrokeConnection => e
          raise ConnectionException.new(
            "Connection to server got interrupted: #{e.message}")
        rescue RestClient::BadGateway => e
          debug "ERROR: Received bad gateway from server, will retry once if this is a GET" if debug?
          retry if (tried += 1) < 2 && request.method.to_s.upcase == "GET"
          raise ConnectionException.new(
            "An error occurred while communicating with the server (#{e.message}). This problem may only be temporary."\
            "#{RestClient.proxy.present? ? " Check that you have correctly specified your proxy server '#{RestClient.proxy}' as well as your OpenShift server '#{request.url}'." : " Check that you have correctly specified your OpenShift server '#{request.url}'."}")
        rescue RestClient::ExceptionWithResponse => e
          auth.retry_auth?(e.response) and retry if auth
          process_error_response(e.response, request.url)
        rescue OpenSSL::SSL::SSLError => e
          raise ConnectionException.new(
            case e.message
            when /certificate verify failed/
              "The server's certificate could not be verified, which means that a secure connection can't be established to the server '#{request.url}'.\n\n"\
              "If your server is using a self-signed certificate, you may disable certificate checks with the -k (or --insecure) option. Using this option means that your data is potentially visible to third parties."
            else
              "A secure connection could not be established to the server (#{e.message}). You may disable secure connections to your server with the -k (or --insecure) option '#{request.url}'.\n\n"\
              "If your server is using a self-signed certificate, you may disable certificate checks with the -k (or --insecure) option. Using this option means that your data is potentially visible to third parties."
            end)
        rescue SocketError => e
          raise ConnectionException.new(
            "Unable to connect to the server (#{e.message})."\
            "#{RestClient.proxy.present? ? " Check that you have correctly specified your proxy server '#{RestClient.proxy}' as well as your OpenShift server '#{request.url}'." : " Check that you have correctly specified your OpenShift server '#{request.url}'."}")
        rescue => e
          logger.debug e.class if debug?
          logger.debug e.backtrace.join("\n  ") if debug?
          raise ResourceAccessException.new(
            "Failed to access resource: #{e.message}")
        ensure
          debug "Response: #{response}" if debug?
        end
      end

      def url
        @end_point
      end

      protected
        include RHC::Helpers

        attr_reader :auth
        def headers
          @headers ||= {:accept => :json}
        end

        def new_request(options)
          # user specified timeout takes presidence
          (options[:headers] ||= {}).reverse_merge!(headers)
          options[:timeout] = $rest_timeout || options[:timeout]
          options[:open_timeout] ||= (options[:timeout] || 4)
          options[:verify_ssl] ||= OpenSSL::SSL::VERIFY_PEER

          auth.to_request(options) if auth
          RestClient::Request.new options
        end

        def parse_response(response)
          result = RHC::Json.decode(response)
          type = result['type']
          data = result['data']
          case type
          when 'domains'
            domains = Array.new
            data.each do |domain_json|
              domains.push(Domain.new(domain_json, self))
            end
            domains
          when 'domain'
            Domain.new(data, self)
          when 'applications'
            apps = Array.new
            data.each do |app_json|
              apps.push(Application.new(app_json, self))
            end
            apps
          when 'application'
            app = Application.new(data, self)
            result['messages'].each do |message|
              app.add_message(message['text']) if message['field'].nil? or message['field'] == 'result'
            end
            app
          when 'cartridges'
            carts = Array.new
            data.each do |cart_json|
              carts.push(Cartridge.new(cart_json, self))
            end
            carts
          when 'cartridge'
            Cartridge.new(data, self)
          when 'user'
            User.new(data, self)
          when 'keys'
            keys = Array.new
            data.each do |key_json|
              keys.push(Key.new(key_json, self))
            end
            keys
          when 'key'
            Key.new(data, self)
          when 'gear_groups'
            gears = Array.new
            data.each do |gear_json|
              gears.push(GearGroup.new(gear_json, self))
            end
            gears
          else
            data
          end
        end

        def generic_error_message(url)
          "The server did not respond correctly. This may be an issue "\
          "with the server configuration or with your connection to the "\
          "server (such as a Web proxy or firewall)."\
          "#{RestClient.proxy.present? ? " Please verify that your proxy server is working correctly (#{RestClient.proxy}) and that you can access the OpenShift server #{url}" : "Please verify that you can access the OpenShift server #{url}"}"
        end

        def process_error_response(response, url=nil)
          messages = []
          parse_error = nil
          begin
            result = RHC::Json.decode(response)
            messages = Array(result['messages'])
          rescue => e
            logger.debug "Response did not include a message from server: #{e.message}" if debug?
            parse_error = ServerErrorException.new(generic_error_message(url), 129)
          end
          case response.code
          when 401
            raise UnAuthorizedException, "Not authenticated"
          when 403
            messages.each do |message|
              if message['severity'].upcase == "ERROR"
                raise RequestDeniedException, message['text']
              end
            end
            raise RequestDeniedException.new("Forbidden")
          when 404
            messages.each do |message|
              if message['severity'].upcase == "ERROR"
                raise ResourceNotFoundException, message['text']
              end
            end
            raise ResourceNotFoundException, generic_error_message(url)
          when 409
            messages.each do |message|
              if message['severity'] and message['severity'].upcase == "ERROR"
                raise ValidationException.new(message['text'], message['field'], message['exit_code'])
              end
            end
          when 422
            e = nil
            messages.each do |message|
              if e and e.field == message["field"]
                e.message << " #{message["text"]}"
              else
                e = ValidationException.new(message["text"], message["field"], message["exit_code"])
              end
            end
            raise e || parse_error || ValidationException.new('Not valid')
          when 400
            messages.each do |message|
              if message['severity'].upcase == "ERROR"
                raise ClientErrorException, message['text']
              end
            end
          when 500
            messages.each do |message|
              if message['severity'].upcase == "ERROR"
                raise ServerErrorException.new(message['text'], message["exit_code"] ? message["exit_code"].to_i : nil)
              end
            end
          when 503
            messages.each do |message|
              if message['severity'].upcase == "ERROR"
                raise ServiceUnavailableException, message['text']
              end
            end
            raise ServiceUnavailableException, generic_error_message(url)
          else
            raise ServerErrorException, "Server returned an unexpected error code: #{response.code}"
          end
          raise parse_error || ServerErrorException.new(generic_error_message(url), 129)
        end

        def add_headers(h)
          h["User-Agent"] = RHC::Helpers.user_agent rescue nil
          add_credentials(h)
        end

        def add_credentials(h)
          if @username
            userpass = "#{@username}:#{@password}"
            # :nocov: version dependent code
            credentials = if RUBY_VERSION.to_f == 1.8
              Base64.encode64(userpass).delete("\n")
            else
              Base64.strict_encode64(userpass)
            end
            # :nocov:
            h["Authorization"] = "Basic #{credentials}"
          end
          h
        end
    end
  end
end
