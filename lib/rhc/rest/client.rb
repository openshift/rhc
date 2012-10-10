require 'base64'
require 'rhc/json'
module RHC
  module Rest
    class Client
      include Rest
      def initialize(end_point, username, password, debug=false)
        # use mydebug for legacy reasons
        @mydebug = @mydebug || debug
        logger.debug "Connecting to #{end_point}" if @mydebug

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
        puts RestClient.proxy
        puts "*"*10
        request = new_request(:url => end_point, :method => :get, :headers => @@headers)
        begin
          response = request.execute
          result = RHC::Json.decode(response)
          @links = request(request)
        rescue => e
          raise ResourceAccessException.new("Resource could not be accessed:#{e.message}")
        end
      end

      #Add Domain
      def add_domain(id)
        logger.debug "Adding domain #{id}" if @mydebug
        url = @links['ADD_DOMAIN']['href']
        method =  @links['ADD_DOMAIN']['method']
        payload = {:id => id}
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Get all Domain
      def domains
        logger.debug "Getting all domains" if @mydebug
        url = @links['LIST_DOMAINS']['href']
        method =  @links['LIST_DOMAINS']['method']
        request = new_request(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end

      #Find Domain by namesapce
      def find_domain(id)
        logger.debug "Finding domain #{id}" if @mydebug
        domains.each { |domain| return domain if domain.id == id }

        raise RHC::DomainNotFoundException.new("Domain #{id} does not exist")
      end

      #Get all Cartridge
      def cartridges
        logger.debug "Getting all cartridges" if @mydebug
        url = @links['LIST_CARTRIDGES']['href']
        method =  @links['LIST_CARTRIDGES']['method']
        request = new_request(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end

      #Find Cartridge by name or regex
      def find_cartridges(name)
        logger.debug "Finding cartridge #{name}" if @mydebug
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

      #Get User info
      def user
        url = @links['GET_USER']['href']
        method =  @links['GET_USER']['method']
        request = new_request(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end

      #find Key by name
      def find_key(name)
        logger.debug "Finding key #{name}" if @mydebug
        user.keys.each { |key| return key if key.name == name }

        raise RHC::KeyNotFoundException.new("Key #{name} does not exist")
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
        logger.debug "Logout/Close client" if @mydebug
      end
      alias :close :logout
    end

    #Application threaddump
    def threaddump(app)
        logger.debug "Threaddump in progress for #{app}" if @mydebug
        url = @links['LIST_DOMAINS']['href']
        method = @links['LIST_DOMAINS']['method']
        request = new_request(:url => url, :method => method, :headers => @@headers)
        response = request(request)
        domain = response.first if not response.empty?
        application = domain.find_application(app)
        return application.threaddump unless application.nil?

        raise RHC::ApplicationNotFoundException.new("Application #{app} does not exist") if application.nil?
    end
  end
end
