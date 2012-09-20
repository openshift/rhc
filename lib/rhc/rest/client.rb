require 'base64'
require 'rhc/json'
require 'rhc/rest/base'

module RHC
  module Rest
    class Client < Base
      def initialize(end_point, username, password, use_debug=false)
        # use mydebug for legacy reasons
        @debug = use_debug
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
        #first get the API
        RestClient.proxy = ENV['http_proxy']
        request = new_request(:url => end_point, :method => :get, :headers => @@headers)

        super :links => request(request)
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
            filtered.push(cart) if cart.name == name and (type.nil? or cart.type == type)
          end
        end
        return filtered
      end

      #find Key by name
      def find_key(name)
        debug "Finding key #{name}"
        user.keys.each { |key| return key if key.name == name }

        raise RHC::KeyNotFoundException.new("Key #{name} does not exist")
      end

      def logout
        #TODO logout
        debug "Logout/Close client"
      end
      alias :close :logout
    end
  end
end
