require 'base64'
require 'rhc/json'
require 'rhc/rest/base'
require 'uri'

module RHC
  module Rest
    class Client < Base
      attr_reader :server_api_versions, :client_api_versions
      # Keep the list of supported API versions here
      # The list may not necessarily be sorted; we will select the last
      # matching one supported by the server.
      # See #api_version_negotiated
      CLIENT_API_VERSIONS = [1.0, 1.1, 1.2]
      
      def initialize(end_point, username, password, use_debug=false, preferred_api_versions = CLIENT_API_VERSIONS)
        @debug = use_debug
        @end_point = end_point
        @server_api_versions = []
        debug "Connecting to #{end_point}"

        credentials = nil
        userpass = "#{username}:#{password}"
        # :nocov: version dependent code
        if RUBY_VERSION.to_f == 1.8
          credentials = Base64.encode64(userpass).delete("\n")
        else
          credentials = Base64.strict_encode64(userpass)
        end
        # :nocov:
        @@headers["Authorization"] = "Basic #{credentials}"
        @@headers["User-Agent"] = RHC::Helpers.user_agent rescue nil
        RestClient.proxy = ENV['http_proxy']
        
        # if API version negotiation is unsuccessful, execute this
        default_request = new_request(:url => @end_point, :method => :get, :headers => @@headers)
        
        # we'll be popping from preferred_api_versions in the while loop below
        # so we need to dup the versions we prefer
        @client_api_versions = preferred_api_versions.dup
        
        begin
          while !api_version_negotiated && !preferred_api_versions.empty?
            api_version = preferred_api_versions.pop
            debug "Checking API version #{api_version}"
            
            @@headers["Accept"] = "application/json; version=#{api_version}"
            request = new_request(:url => @end_point, :method => :get, :headers => @@headers)
            begin
              json_response = ::RHC::Json.decode(request.execute)
              @server_api_versions = json_response['supported_api_versions']
              links = json_response['data']
            rescue RestClient::NotAcceptable
              # try the next version
              debug "Server does not support API version #{api_version}"
            end
          end
          debug "Using API version #{api_version_negotiated}" if api_version_negotiated
          warn_about_api_versions
        rescue Exception => e
          raise ResourceAccessException.new("Failed to access resource: #{e.message}")
        end
        super({:links => links || request(default_request)}, use_debug)
      end

      def add_domain(id)
        debug "Adding domain #{id}"
        rest_method "ADD_DOMAIN", :id => id
      end

      def domains
        debug "Getting all domains"
        rest_method "LIST_DOMAINS"
      end

      def cartridges
        debug "Getting all cartridges"
        rest_method "LIST_CARTRIDGES"
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
      
      # return the API version that the server and this client agreed on
      def api_version_negotiated
        return nil unless @server_api_versions
        client_api_versions.reverse. # choose the last API version listed
          detect { |v| @server_api_versions.include? v }
      end
      
      def api_version_current?
        current_client_api_version == api_version_negotiated
      end
      
      def current_client_api_version
        client_api_versions.last
      end
      
      def warn_about_api_versions
        if !api_version_match?
          # API versions did not match
          warn "WARNING: API version mismatch. This client supports #{client_api_versions.join(', ')} 
but server at #{URI.parse(@end_point).host} supports #{@server_api_versions.join(', ')}."
        end
      end
    end
  end
end
