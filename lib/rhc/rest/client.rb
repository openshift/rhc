require 'rhc/json'
require 'rhc/helpers'
require 'uri'
require 'logger'
require 'httpclient'
require 'benchmark'
require 'set'

module RHC
  module Rest

    #
    # These are methods that belong to the API object but are
    # callable from the client for convenience.
    #
    module ApiMethods
      def add_domain(id, payload={})
        debug "Adding domain #{id} with options #{payload.inspect}"
        @domains = nil
        payload.delete_if{ |k,v| k.nil? or v.nil? }
        api.rest_method "ADD_DOMAIN", {:id => id}.merge(payload)
      end

      def domains
        debug "Getting all domains"
        @domains ||= api.rest_method "LIST_DOMAINS"
      end

      def owned_domains
        debug "Getting owned domains"
        if link = api.link_href(:LIST_DOMAINS_BY_OWNER)
          @owned_domains ||= api.rest_method 'LIST_DOMAINS_BY_OWNER', :owner => '@self'
        else
          domains
        end
      end

      def applications(options={})
        if link = api.link_href(:LIST_APPLICATIONS)
          api.rest_method :LIST_APPLICATIONS, options
        else
          self.domains.map{ |d| d.applications(options) }.flatten
        end
      end

      def cartridges
        debug "Getting all cartridges"
        @cartridges ||= api.rest_method("LIST_CARTRIDGES", nil, :lazy_auth => true)
      end

      def user
        debug "Getting user info"
        @user ||= api.rest_method "GET_USER"
      end

      #Find Domain by namesapce
      def find_domain(id)
        debug "Finding domain #{id}"
        if link = api.link_href(:SHOW_DOMAIN, ':name' => id)
          request(:url => link, :method => "GET")
        else
          domains.find{ |d| d.name.downcase == id.downcase }
        end or raise DomainNotFoundException.new("Domain #{id} not found")
      end

      def find_application(domain, application, options={})
        request(:url => link_show_application_by_domain_name(domain, application), :method => "GET", :payload => options)
      end

      def find_application_gear_groups(domain, application, options={})
        request(:url => link_show_application_by_domain_name(domain, application, "gear_groups"), :method => "GET", :payload => options)
      end

      def find_application_aliases(domain, application, options={})
        request(:url => link_show_application_by_domain_name(domain, application, "aliases"), :method => "GET", :payload => options)
      end

      def find_application_by_id(id, options={})
        if api.supports? :show_application
          request(:url => link_show_application_by_id(id), :method => "GET", :payload => options)
        else
          applications.find{ |a| a.id == id }
        end or raise ApplicationNotFoundException.new("Application with id #{id} not found")
      end

      def find_application_by_id_gear_groups(id, options={})
        if api.supports? :show_application
          request(:url => link_show_application_by_id(id, 'gear_groups'), :method => "GET", :payload => options)
        else
          applications.find{ |a| return a.gear_groups if a.id == id }
        end or raise ApplicationNotFoundException.new("Application with id #{id} not found")
      end

      def link_show_application_by_domain_name(domain, application, *args)
        [
          api.links['LIST_DOMAINS']['href'],
          domain,
          "applications",
          application,
        ].concat(args).map{ |s| URI.escape(s) }.join("/")
      end

      def link_show_application_by_id(id, *args)
        api.link_href(:SHOW_APPLICATION, {':id' => id}, *args)
      end

      def link_show_domain_by_name(domain, *args)
        api.link_href(:SHOW_DOMAIN, ':id' => domain)
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

      def reset
        (instance_variables - [
          :@end_point, :@debug, :@preferred_api_versions, :@auth, :@options, :@headers,
          :@last_options, :@httpclient, :@self_signed, :@current_api_version, :@api
        ]).each{ |sym| instance_variable_set(sym, nil) }
        self
      end
    end

    class Client < Base
      include ApiMethods

      # Keep the list of supported API versions here
      # The list may not necessarily be sorted; we will select the last
      # matching one supported by the server.
      # See #api_version_negotiated
      CLIENT_API_VERSIONS = [1.1, 1.2, 1.3, 1.4, 1.5]
      MAX_RETRIES = 5

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

        @auth = options.delete(:auth)

        self.headers.merge!(options.delete(:headers)) if options[:headers]
        self.options.merge!(options)

        debug "Connecting to #{@end_point}"
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

      def attempt(retries, &block)
        (0..retries).each do |i|
          yield i < (retries-1), i
        end
        raise "Too many retries, giving up."
      end

      def request(options, &block)
        attempt(MAX_RETRIES) do |more, i|
          begin
            client, args = new_request(options.dup)
            auth = options[:auth] || self.auth
            response = nil

            debug "Request #{args[0].to_s.upcase} #{args[1]}#{"?#{args[2].map{|a| a.join('=')}.join(' ')}" if args[2] && args[0] == 'GET'}"
            time = Benchmark.realtime{ response = client.request(*(args << true)) }
            debug "   code %s %4i ms" % [response.status, (time*1000).to_i] if response

            next if more && retry_proxy(response, i, args, client)
            auth.retry_auth?(response, self) and next if more && auth
            handle_error!(response, args[1], client) unless response.ok?

            return (if block_given?
                yield response
              else
                parse_response(response.content) unless response.nil? or response.code == 204
              end)
          rescue HTTPClient::BadResponseError => e
            if e.res
              debug "Response: #{e.res.status} #{e.res.headers.inspect}\n#{e.res.content}\n-------------" if debug?

              next if more && retry_proxy(e.res, i, args, client)
              auth.retry_auth?(e.res, self) and next if more && auth
              handle_error!(e.res, args[1], client)
            end
            raise ConnectionException.new(
              "An unexpected error occured when connecting to the server: #{e.message}")
          rescue HTTPClient::TimeoutError => e
            raise TimeoutException.new(
              "Connection to server timed out. "\
              "It is possible the operation finished without being able "\
              "to report success. Use 'rhc domain show' or 'rhc app show' "\
              "to see the status of your applications.", e)
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
          rescue Errno::ECONNRESET => e
            raise ConnectionException.new(
              "The server has closed the connection unexpectedly (#{e.message}). Your last operation may still be running on the server; please check before retrying your last request.")
          rescue RHC::Rest::Exception
            raise
          rescue => e
            debug_error(e)
            raise ConnectionException, "An unexpected error occured: #{e.message}", e.backtrace
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

        def httpclient_for(options, auth=nil)
          user, password, token = options.delete(:user), options.delete(:password), options.delete(:token)

          if !@httpclient || @last_options != options
            @httpclient = RHC::Rest::HTTPClient.new(:agent_name => user_agent).tap do |http|
              debug "Created new httpclient"
              http.cookie_manager = nil
              http.debug_dev = $stderr if ENV['HTTP_DEBUG']

              options.select{ |sym, value| http.respond_to?("#{sym}=") }.each{ |sym, value| http.send("#{sym}=", value) }

              ssl = http.ssl_config
              options.select{ |sym, value| ssl.respond_to?("#{sym}=") }.each{ |sym, value| ssl.send("#{sym}=", value) }
              ssl.add_trust_ca(options[:ca_file]) if options[:ca_file]
              ssl.verify_callback = default_verify_callback

              @last_options = options
            end
          end
          if auth && auth.respond_to?(:to_httpclient)
            auth.to_httpclient(@httpclient, options)
          else
            @httpclient.www_auth.basic_auth.set(@end_point, user, password) if user
            @httpclient.www_auth.oauth2.set_token(@end_point, token) if token
          end
          @httpclient
        end

        def default_verify_callback
          lambda do |is_ok, ctx|
            @self_signed = false
            unless is_ok
              cert = ctx.current_cert
              if cert && (cert.subject.cmp(cert.issuer) == 0)
                @self_signed = true
                debug "SSL Verification failed -- Using self signed cert"
              else
                debug "SSL Verification failed -- Preverify: #{is_ok}, Error: #{ctx.error_string} (#{ctx.error})"
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
          options.delete(:accept)

          args = [options.delete(:method), options.delete(:url), query, payload, headers, true]
          [httpclient_for(options, auth), args]
        end

        def retry_proxy(response, i, args, client)
          if response.status == 502
            debug "ERROR: Received bad gateway from server, will retry once if this is a GET"
            return true if i == 0 && args[0] == :get
            raise ConnectionException.new(
              "An error occurred while communicating with the server. This problem may only be temporary."\
              "#{client.proxy.present? ? " Check that you have correctly specified your proxy server '#{client.proxy}' as well as your OpenShift server '#{args[1]}'." : " Check that you have correctly specified your OpenShift server '#{args[1]}'."}")
          end
        end

        def parse_response(response)
          result = RHC::Json.decode(response)
          type = result['type']
          data = result['data'] || {}

          parse_messages result, data

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
          when 'environment-variables'
            data.map{ |json| EnvironmentVariable.new(json, self) }
          when 'deployments'
            data.map{ |json| Deployment.new(json, self) }
          else
            data
          end
        end

        def parse_messages(result, data)
          warnings, messages = Array(result['messages']).inject([[],[]]) do |a, m|
            severity, field, text = m.values_at('severity', 'field', 'text')
            text.gsub!(/\A\n+/m, "")
            text.rstrip!
            case severity
            when 'warning'
              a[0] << text
            when 'debug'
              a[1] << text if debug?
            when 'info'
              a[1] << text if debug? || field == 'result'
            else
              a[1] << text
            end
            a
          end

          if data.is_a?(Array)
            data.each do |d|
              d['messages'] = messages
              d['warnings'] = warnings
            end
          elsif data.is_a?(Hash)
            data['messages'] = messages
            data['warnings'] = warnings
          end

          warnings.each do |warning|
            # Prevent repeated warnings during the same client session
            if !defined?(@warning_map) || !@warning_map.include?(warning)
              @warning_map ||= Set.new
              @warning_map << warning
              warn warning
            end
          end if respond_to? :warn
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
            debug "Response did not include a message from server: #{e.message}"
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
