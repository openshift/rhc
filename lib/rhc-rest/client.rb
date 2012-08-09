require 'base64'
require 'rhc/json'

module Rhc
  module Rest
    class Client
      include Rest
      def initialize(end_point, username, password, debug=false)
        # use mydebug for legacy reasons
        @mydebug = @mydebug || debug
        logger.debug "Connecting to #{end_point}" if @mydebug
        credentials = Base64.encode64("#{username}:#{password}")
        @@headers["Authorization"] = "Basic #{credentials}"
        @@headers["User-Agent"] = RHC::Helpers.user_agent rescue nil
        #first get the API
        RestClient.proxy = ENV['http_proxy']
        request = RestClient::Request.new(:url => end_point, :method => :get, :headers => @@headers)
        begin
          response = request.execute
          result = RHC::Json.decode(response)
          @links = request(request)
        rescue RestClient::ExceptionWithResponse => e
            logger.error "Failed to get API #{e.response}"
        rescue Exception => e
          raise ResourceAccessException.new("Resource could not be accessed:#{e.message}")
        end
      end

      #Add Domain
      def add_domain(id)
        logger.debug "Adding domain #{id}" if @mydebug
        url = @links['ADD_DOMAIN']['href']
        method =  @links['ADD_DOMAIN']['method']
        payload = {:id => id}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Get all Domain
      def domains
        logger.debug "Getting all domains" if @mydebug
        url = @links['LIST_DOMAINS']['href']
        method =  @links['LIST_DOMAINS']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
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
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end

      #Find Cartridge by name
      def find_cartridge(name)
        logger.debug "Finding cartridge #{name}" if @mydebug
        filtered = Array.new
        cartridges.each do |cart|
          if cart.name == name
          filtered.push(cart)
          end
        end
        return filtered
      end

      #Get User info
      def user
        url = @links['GET_USER']['href']
        method =  @links['GET_USER']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end

      #find Key by name
      def find_key(name)
        logger.debug "Finding key #{name}" if @mydebug
        user.keys.each { |key| return key if key.name == name }

        raise RHC::KeyNotFoundException.new("Key #{name} does not exist")
      end

      def logout
        #TODO logout
        logger.debug "Logout/Close client" if @mydebug
      end
      alias :close :logout
    end

  end
end
