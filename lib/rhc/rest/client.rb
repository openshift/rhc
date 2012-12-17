require 'base64'
require 'rhc/json'
require 'rhc/rest/base'
require 'rhc/helpers'
require 'uri'

module RHC
  module Rest
    class Client < Base
      include RHC::Helpers
      
      attr_reader :server_api_versions, :client_api_versions
      # Keep the list of supported API versions here
      # The list may not necessarily be sorted; we will select the last
      # matching one supported by the server.
      # See #api_version_negotiated
      CLIENT_API_VERSIONS = [1.1, 1.2, 1.3]
      
      def initialize(end_point, username, password, use_debug=false, preferred_api_versions = CLIENT_API_VERSIONS)
        @debug = use_debug
        @end_point = end_point
        @server_api_versions = []
        @username, @password = username, password
        debug "Connecting to #{end_point}"

        add_headers(headers)
        RestClient.proxy = URI.parse(ENV['http_proxy']).to_s if ENV['http_proxy']

        # API version negotiation
        begin
          debug "Client supports API versions #{preferred_api_versions.join(', ')}"
          @client_api_versions = preferred_api_versions
          default_request = new_request(:url => @end_point, :method => :get, :headers => @@headers)
          @server_api_versions, links = api_info(default_request)
          debug "Server supports API versions #{@server_api_versions.join(', ')}"

          if api_version_negotiated
            unless server_api_version_current?
              debug "Client API version #{api_version_negotiated} is not current. Refetching API"
              # need to re-fetch API
              @@headers["Accept"] = "application/json; version=#{api_version_negotiated}"
              req = new_request(:url => @end_point, :method => :get, :headers => @@headers)
              @server_api_versions, links = api_info req
            end
          else
            warn_about_api_versions
          end
        rescue RHC::Rest::ResourceNotFoundException => e
          raise ApiEndpointNotFound.new(
            "The OpenShift server is not responding correctly.  Check "\
            "that '#{end_point}' is the correct URL for your server. "\
            "The server may be offline or misconfigured.")
        end

        super({:links => links}, use_debug)
      end

      def add_domain(id)
        debug "Adding domain #{id}"
        @domains = nil
        rest_method "ADD_DOMAIN", :id => id
      end

      def domains
        debug "Getting all domains"
        @domains ||= rest_method "LIST_DOMAINS"
      end

      def cartridges
        debug "Getting all cartridges"
        rest_method("LIST_CARTRIDGES")
      end

      def user
        debug "Getting user info"
        rest_method "GET_USER"
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
      
      
      ### API version related methods
      def api_version_match?
        ! api_version_negotiated.nil?
      end
      
      # return the API version that the server and this client can agree on
      def api_version_negotiated
        client_api_versions.reverse. # choose the last API version listed
          detect { |v| @server_api_versions.include? v }
      end
      
      def client_api_version_current?
        current_client_api_version == api_version_negotiated
      end
      
      def current_client_api_version
        client_api_versions.last
      end
      
      def server_api_version_current?
        @server_api_versions && @server_api_versions.max == api_version_negotiated
      end
      
      def warn_about_api_versions
        if !api_version_match?
          warn "WARNING: API version mismatch. This client supports #{client_api_versions.join(', ')} but
server at #{URI.parse(@end_point).host} supports #{@server_api_versions.join(', ')}."
          warn "The client version may be outdated; please consider updating 'rhc'. We will continue, but you may encounter problems."
        end
      end

      def debug?
        @debug
      end

      protected
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


      private
        # execute +req+ with RestClient, and return [server_api_versions, links]
        def api_info(req)
          request(req) do |response|
            json_response = ::RHC::Json.decode(response)
            [ json_response['supported_api_versions'], json_response['data'] ]
          end
        end
    end
  end
end
