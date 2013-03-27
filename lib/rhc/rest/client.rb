require 'rhc/json'
require 'rhc/helpers'
require 'uri'
require 'logger'
require 'httpclient'
require 'benchmark'

module RHC
  module Rest

    MAX_RETRIES = 5

    #
    # These are methods that belong to the API object but are
    # callable from the client for convenience.
    #
    module ApiMethods
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
        @cartridges ||= api.rest_method("LIST_CARTRIDGES", nil, :lazy_auth => true)
      end

      def user
        debug "Getting user info"
        @user ||= api.rest_method "GET_USER"
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

        raise DomainNotFoundException.new("Domain #{id} not found")
      end

      def find_application(domain, application, options={})
        response = request({
          :url => link_show_application_by_domain_name(domain, application),
          :method => "GET",
          :payload => options
        })
      end

      def find_application_gear_groups(domain, application, options={})
        response = request({
          :url => link_show_application_by_domain_name(domain, application, "gear_groups"),
          :method => "GET",
          :payload => options
        })
      end

      def find_application_aliases(domain, application, options={})
        response = request({
          :url => link_show_application_by_domain_name(domain, application, "aliases"),
          :method => "GET",
          :payload => options
        })
      end

      def link_show_application_by_domain_name(domain, application, *args)
        [
          api.links['LIST_DOMAINS']['href'],
          domain,
          "applications",
          application,
        ].concat(args).map{ |s| URI.escape(s) }.join("/")
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

      def supports_sessions?
        api.supports? 'ADD_AUTHORIZATION'
      end

      def authorizations
        raise AuthorizationsNotSupported unless supports_sessions?
        api.rest_method 'LIST_AUTHORIZATIONS'
      end

      #
      # Returns nil if creating sessions is not supported, raises on error, otherwise
      # returns an Authorization object.
      #
      def new_session(options={})
        if supports_sessions?
          api.rest_method('ADD_AUTHORIZATION', {
            :scope => 'session',
            :note => "RHC/#{RHC::VERSION::STRING} (from #{Socket.gethostname rescue 'unknown'} on #{RUBY_PLATFORM})",
            :reuse => true
          }, options)
        end
      end

      def add_authorization(options={})
        raise AuthorizationsNotSupported unless supports_sessions?
        api.rest_method('ADD_AUTHORIZATION', options, options)
      end

      def delete_authorizations
        raise AuthorizationsNotSupported unless supports_sessions?
        api.rest_method('LIST_AUTHORIZATIONS', nil, {:method => :delete})
      end

      def delete_authorization(token)
        raise AuthorizationsNotSupported unless supports_sessions?
        api.rest_method('SHOW_AUTHORIZATION', nil, {:method => :delete, :params => {':id' => token}})
      end

      def authorization_scope_list
        raise AuthorizationsNotSupported unless supports_sessions?
        link = api.links['ADD_AUTHORIZATION']
        scope = link['optional_params'].find{ |h| h['name'] == 'scope' }
        scope['description'].scan(/(?!\n)\*(.*?)\n(.*?)(?:\n|\Z)/m).inject([]) do |h, (a, b)|
          h << [a.strip, b.strip] if a.present? && b.present?
          h
        end
      end

      def logout
        #TODO logout
        debug "Logout/Close client"
      end
      alias :close :logout
    end

    class Client < Base
      include ApiMethods

      # Keep the list of supported API versions here
      # The list may not necessarily be sorted; we will select the last
      # matching one supported by the server.
      # See #api_version_negotiated
      CLIENT_API_VERSIONS = [1.1, 1.2, 1.3, 1.4]

      # Set the http_proxy env variable, read by
      # HTTPClient, being sure to add the http protocol
      # if not specified already
      proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']
      if proxy && proxy !~ /^(\w+):\/\// then
        ENV['http_proxy'] = "http://#{proxy}"
      end

      def initialize(*args)
        options = args[0].is_a?(Hash) && args[0] || {}
        @end_point, @debug, @preferred_api_versions =
          if options.empty?
            options[:user] = args.delete_at(1)
            options[:password] = args.delete_at(1)
            args
          else
            [
              options.delete(:url) ||
                (options[:server] && "https://#{options.delete(:server)}/broker/rest/api"),
              options.delete(:debug),
              options.delete(:preferred_api_versions)
            ]
          end

        @preferred_api_versions ||= CLIENT_API_VERSIONS
        @debug ||= false

        if options[:token]
          self.headers[:authorization] = "Bearer #{options.delete(:token)}"
          options.delete(:user)
          options.delete(:password)
        end

        @auth = options.delete(:auth)

        self.headers.merge!(options.delete(:headers)) if options[:headers]
        self.options.merge!(options)

        debug "Connecting to #{@end_point}"
      end

      def debug?
        @debug
      end

      def url
        @end_point
      end

      def api
        @api ||= RHC::Rest::Api.new(self, @preferred_api_versions).tap do |api|
          self.current_api_version = api.api_version_negotiated
        end
      end

      def api_version_negotiated
        api
        current_api_version
      end

      def request(options, &block)
        (0..MAX_RETRIES).each do |i|
          begin
            client, args = new_request(options.dup)
            auth = options[:auth] || self.auth
            response = nil

            debug "Request #{args[0].to_s.upcase} #{args[1]}" if debug?
            time = Benchmark.realtime{ response = client.request(*(args << true)) }
            debug "   code %s %4i ms" % [response.status, (time*1000).to_i] if debug? && response

            next if retry_proxy(response, i, args, client)
            auth.retry_auth?(response, self) and next if auth
            handle_error!(response, args[1], client) unless response.ok?

            break (if block_given?
                yield response
              else
                parse_response(response.content) unless response.nil? or response.code == 204
              end)
          rescue HTTPClient::BadResponseError => e
            if e.res
              debug "Response: #{e.res.status} #{e.res.headers.inspect}\n#{e.res.content}\n-------------" if debug?

              next if retry_proxy(e.res, i, args, client)
              auth.retry_auth?(e.res, self) and next if auth
              handle_error!(e.res, args[1], client)
            end
            raise ConnectionException.new(
              "An unexpected error occured when connecting to the server: #{e.message}")
          rescue HTTPClient::TimeoutError => e
            raise TimeoutException.new(
              "Connection to server timed out. "\
              "It is possible the operation finished without being able "\
              "to report success. Use 'rhc domain show' or 'rhc app show' "\
              "to see the status of your applications.")
          rescue EOFError => e
            raise ConnectionException.new(
              "Connection to server got interrupted: #{e.message}")
          rescue OpenSSL::SSL::SSLError => e
            raise SelfSignedCertificate.new(
              'self signed certificate',
              "The server is using a self-signed certificate, which means that a secure connection can't be established '#{args[1]}'.\n\n"\
              "You may disable certificate checks with the -k (or --insecure) option. Using this option means that your data is potentially visible to third parties.") if self_signed?
            raise case e.message
              when /self signed certificate/
                CertificateVerificationFailed.new(
                  e.message,
                  "The server is using a self-signed certificate, which means that a secure connection can't be established '#{args[1]}'.\n\n"\
                  "You may disable certificate checks with the -k (or --insecure) option. Using this option means that your data is potentially visible to third parties.")
              when /certificate verify failed/
                CertificateVerificationFailed.new(
                  e.message,
                  "The server's certificate could not be verified, which means that a secure connection can't be established to the server '#{args[1]}'.\n\n"\
                  "If your server is using a self-signed certificate, you may disable certificate checks with the -k (or --insecure) option. Using this option means that your data is potentially visible to third parties.")
              when /unable to get local issuer certificate/
                SSLConnectionFailed.new(
                  e.message,
                  "The server's certificate could not be verified, which means that a secure connection can't be established to the server '#{args[1]}'.\n\n"\
                  "You may need to specify your system CA certificate file with --ssl-ca-file=<path_to_file>. If your server is using a self-signed certificate, you may disable certificate checks with the -k (or --insecure) option. Using this option means that your data is potentially visible to third parties.")
              when /^SSL_connect returned=1 errno=0 state=SSLv2\/v3 read server hello A/
                SSLVersionRejected.new(
                  e.message,
                  "The server has rejected your connection attempt with an older SSL protocol.  Pass --ssl-version=sslv3 on the command line to connect to this server.")
              when /^SSL_CTX_set_cipher_list:: no cipher match/
                SSLVersionRejected.new(
                  e.message,
                  "The server has rejected your connection attempt because it does not support the requested SSL protocol version.\n\n"\
                  "Check with the administrator for a valid SSL version to use and pass --ssl-version=<version> on the command line to connect to this server.")
              else
                SSLConnectionFailed.new(
                  e.message,
                  "A secure connection could not be established to the server (#{e.message}). You may disable secure connections to your server with the -k (or --insecure) option '#{args[1]}'.\n\n"\
                  "If your server is using a self-signed certificate, you may disable certificate checks with the -k (or --insecure) option. Using this option means that your data is potentially visible to third parties.")
              end
          rescue SocketError, Errno::ECONNREFUSED => e
            raise ConnectionException.new(
              "Unable to connect to the server (#{e.message})."\
              "#{client.proxy.present? ? " Check that you have correctly specified your proxy server '#{client.proxy}' as well as your OpenShift server '#{args[1]}'." : " Check that you have correctly specified your OpenShift server '#{args[1]}'."}")
          rescue RHC::Rest::Exception
            raise
          rescue => e
            if debug?
              logger.debug "#{e.message} (#{e.class})"
              logger.debug e.backtrace.join("\n  ")
            end
            raise ConnectionException.new("An unexpected error occured: #{e.message}").tap{ |n| n.set_backtrace(e.backtrace) }
          end
        end
      end

      protected
        include RHC::Helpers

        attr_reader :auth
        attr_accessor :current_api_version
        def headers
          @headers ||= {
            :accept => :json
          }
        end

        def user_agent
          RHC::Helpers.user_agent
        end

        def options
          @options ||= {
          }
        end

        def httpclient_for(options)
          return @httpclient if @last_options == options
          @httpclient = HTTPClient.new(:agent_name => user_agent).tap do |http|
            http.cookie_manager = nil
            http.debug_dev = $stderr if ENV['HTTP_DEBUG']

            options.select{ |sym, value| http.respond_to?("#{sym}=") }.map{ |sym, value| http.send("#{sym}=", value) }
            http.set_auth(nil, options[:user], options[:password]) if options[:user]

            ssl = http.ssl_config
            options.select{ |sym, value| ssl.respond_to?("#{sym}=") }.map{ |sym, value| ssl.send("#{sym}=", value) }
            ssl.add_trust_ca(options[:ca_file]) if options[:ca_file]
            ssl.verify_callback = default_verify_callback

            @last_options = options
          end
        end

        def default_verify_callback
          lambda do |is_ok, ctx|
            @self_signed = false
            unless is_ok
              cert = ctx.current_cert
              if cert && (cert.subject.cmp(cert.issuer) == 0)
                @self_signed = true
                debug "SSL Verification failed -- Using self signed cert" if debug?
              else
                debug "SSL Verification failed -- Preverify: #{is_ok}, Error: #{ctx.error_string} (#{ctx.error})" if debug?
              end
              return false
            end
            true
          end
        end
        def self_signed?
          @self_signed
        end

        def new_request(options)
          options.reverse_merge!(self.options)

          options[:connect_timeout] ||= options[:timeout] || 120
          options[:receive_timeout] ||= options[:timeout] || 0
          options[:send_timeout] ||= options[:timeout] || 0
          options[:timeout] = nil

          if auth = options[:auth] || self.auth
            auth.to_request(options)
          end

          headers = (self.headers.to_a + (options.delete(:headers) || []).to_a).inject({}) do |h,(k,v)|
            v = "application/#{v}" if k == :accept && v.is_a?(Symbol)
            h[k.to_s.downcase.gsub(/_/, '-')] = v
            h
          end

          user = options.delete(:user)
          password = options.delete(:password)
          if user
            headers['Authorization'] ||= "Basic #{["#{user}:#{password}"].pack('m').tr("\n", '')}"
          end

          modifiers = []
          version = options.delete(:api_version) || current_api_version
          modifiers << ";version=#{version}" if version

          query = options.delete(:query) || {}
          payload = options.delete(:payload)
          if options[:method].to_s.upcase == 'GET'
            query = payload
            payload = nil
          else
            headers['content-type'] ||= begin
                payload = payload.to_json unless payload.nil? || payload.is_a?(String)
                "application/json#{modifiers.join}"
              end
          end
          query = nil if query.blank?

          if headers['accept'] && modifiers.present?
            headers['accept'] << modifiers.join
          end

          # remove all unnecessary options
          options.delete(:lazy_auth)

          args = [options.delete(:method), options.delete(:url), query, payload, headers, true]
          [httpclient_for(options), args]
        end

        def retry_proxy(response, i, args, client)
          if response.status == 502
            debug "ERROR: Received bad gateway from server, will retry once if this is a GET" if debug?
            return true if i == 0 && args[0] == :get
            raise ConnectionException.new(
              "An error occurred while communicating with the server. This problem may only be temporary."\
              "#{client.proxy.present? ? " Check that you have correctly specified your proxy server '#{client.proxy}' as well as your OpenShift server '#{args[1]}'." : " Check that you have correctly specified your OpenShift server '#{args[1]}'."}")
          end
        end

        def parse_response(response)
          result = RHC::Json.decode(response)
          type = result['type']
          data = result['data']

          # Copy messages to each object
          messages = Array(result['messages']).map do |m|
            m['text'] if m['field'].nil? or m['field'] == 'result'
          end.compact
          data.each{ |d| d['messages'] = messages } if data.is_a?(Array)
          data['messages'] = messages if data.is_a?(Hash)

          case type
          when 'domains'
            data.map{ |json| Domain.new(json, self) }
          when 'domain'
            Domain.new(data, self)
          when 'authorization'
            Authorization.new(data, self)
          when 'authorizations'
            data.map{ |json| Authorization.new(json, self) }
          when 'applications'
            data.map{ |json| Application.new(json, self) }
          when 'application'
            Application.new(data, self)
          when 'cartridges'
            data.map{ |json| Cartridge.new(json, self) }
          when 'cartridge'
            Cartridge.new(data, self)
          when 'user'
            User.new(data, self)
          when 'keys'
            data.map{ |json| Key.new(json, self) }
          when 'key'
            Key.new(data, self)
          when 'gear_groups'
            data.map{ |json| GearGroup.new(json, self) }
          when 'aliases'
            data.map{ |json| Alias.new(json, self) }
          else
            data
          end
        end

        def raise_generic_error(url, client)
          raise ServerErrorException.new(generic_error_message(url, client), 129)
        end
        def generic_error_message(url, client)
          "The server did not respond correctly. This may be an issue "\
          "with the server configuration or with your connection to the "\
          "server (such as a Web proxy or firewall)."\
          "#{client.proxy.present? ? " Please verify that your proxy server is working correctly (#{client.proxy}) and that you can access the OpenShift server #{url}" : " Please verify that you can access the OpenShift server #{url}"}"
        end

        def handle_error!(response, url, client)
          messages = []
          parse_error = nil
          begin
            result = RHC::Json.decode(response.content)
            messages = Array(result['messages'])
            messages.delete_if do |m|
              m.delete_if{ |k,v| k.nil? || v.blank? } if m.is_a? Hash
              m.blank?
            end
          rescue => e
            logger.debug "Response did not include a message from server: #{e.message}" if debug?
          end
          case response.status
          when 400
            raise_generic_error(url, client) if messages.empty?
            message, keys = messages_to_fields(messages)
            raise ValidationException.new(message || "The operation could not be completed.", keys)
          when 401
            raise UnAuthorizedException, "Not authenticated"
          when 403
            raise RequestDeniedException, messages_to_error(messages) || "You are not authorized to perform this operation."
          when 404
            if messages.length == 1
              case messages.first['exit_code']
              when 127
                raise DomainNotFoundException, messages_to_error(messages) || generic_error_message(url, client)
              when 101
                raise ApplicationNotFoundException, messages_to_error(messages) || generic_error_message(url, client)
              end
            end
            raise ResourceNotFoundException, messages_to_error(messages) || generic_error_message(url, client)
          when 409
            raise_generic_error(url, client) if messages.empty?
            message, keys = messages_to_fields(messages)
            raise ValidationException.new(message || "The operation could not be completed.", keys)
          when 422
            raise_generic_error(url, client) if messages.empty?
            message, keys = messages_to_fields(messages)
            raise ValidationException.new(message || "The operation was not valid.", keys)
          when 400
            raise ClientErrorException, messages_to_error(messages) || "The server did not accept the requested operation."
          when 500
            raise ServerErrorException, messages_to_error(messages) || generic_error_message(url, client)
          when 503
            raise ServiceUnavailableException, messages_to_error(messages) || generic_error_message(url, client)
          else
            raise ServerErrorException, messages_to_error(messages) || "Server returned an unexpected error code: #{response.status}"
          end
          raise_generic_error
        end

      private
        def logger
          @logger ||= Logger.new(STDOUT)
        end

        def messages_to_error(messages)
          errors, remaining = messages.partition{ |m| (m['severity'] || "").upcase == 'ERROR' }
          if errors.present?
            if errors.length == 1
              errors.first['text']
            else
              "The server reported multiple errors:\n* #{errors.map{ |m| m['text'] || "An unknown server error occurred.#{ " (exit code: #{m['exit_code']}" if m['exit_code']}}" }.join("\n* ")}"
            end
          elsif remaining.present?
            "The operation did not complete successfully, but the server returned additional information:\n* #{remaining.map{ |m| m['text'] || 'No message'}.join("\n* ")}"
          end
        end

        def messages_to_fields(messages)
          keys = messages.group_by{ |m| m['field'] }.keys.compact.sort.map(&:to_sym) rescue []
          [messages_to_error(messages), keys]
        end
    end
  end
end
