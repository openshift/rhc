require 'base64'

module Rhc
  module Rest
    class Client
      include Rest
      def initialize(end_point, username, password)
        @@end_point = end_point
        credentials = Base64.encode64("#{username}:#{password}")
        @@headers["Authorization"] = "Basic #{credentials}"
        #first get the API
        request = RestClient::Request.new(:url => @@end_point + "/api", :method => :get, :headers => @@headers)
        begin
          response = request.execute
          result = JSON.parse(response)
          @links = send(request)
        rescue RestClient::ExceptionWithResponse => e
            logger.error "Failed to get API #{e.response}"
        rescue Exception => e
          raise ResourceAccessException.new("Resource could not be accessed:#{e.message}")
        end
      end

      #Add Domain
      def add_domain(id)
        logger.debug "Adding domain #{id}"
        url = @@end_point + @links['ADD_DOMAIN']['href']
        method =  @links['ADD_DOMAIN']['method']
        payload = {:id => id}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Get all Domain
      def domains
        logger.debug "Getting all domains"
        url = @@end_point + @links['LIST_DOMAINS']['href']
        method =  @links['LIST_DOMAINS']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      #Find Domain by namesapce
      def find_domain(id)
        logger.debug "Finding domain #{id}"
        filtered = Array.new
        domains.each do |domain|
        #TODO do a regex caomparison
          if domain.id == id
          filtered.push(domain)
          end
        end
        return filtered
      end

      #Find Application by name
      def find_application(name)
        logger.debug "Finding application #{name}"
        filtered = Array.new
        domains.each do |domain|
        #TODO do a regex caomparison
          domain.applications.each do |app|
            if app.name == name
            filtered.push(app)
            end
          end
        end
        return filtered
      end

      #Get all Cartridge
      def cartridges
        logger.debug "Getting all cartridges"
        url = @@end_point + @links['LIST_CARTRIDGES']['href']
        method =  @links['LIST_CARTRIDGES']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      #Find Cartridge by name
      def find_cartridge(name)
        logger.debug "Finding cartridge #{name}"
        filtered = Array.new
        cartridges.each do |cart|
        #TODO do a regex caomparison
          if cart.name == name
          filtered.push(cart)
          end
        end
        return filtered
      end

      #Get User info
      def user
        url = @@end_point + @links['GET_USER']['href']
        method =  @links['GET_USER']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      #find Key by name
      def find_key(name)
        logger.debug "Finding key #{name}"
        filtered = Array.new
        user.keys.each do |key|
        #TODO do a regex caomparison
          if key.name == name
          filtered.push(key)
          end
        end
        return filtered
      end

      def logout
        #TODO logout
        logger.debug "Logout/Close client"
      end
      alias :close :logout
    end

  end
end
