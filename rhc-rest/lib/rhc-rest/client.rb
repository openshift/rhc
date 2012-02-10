module Rhc
  module Rest
    class Client
      include Rest
      def initialize(end_point, username, password)
        @@end_point = end_point
        @username = username
        @password = password
        request = RestClient::Request.new(:url => @@end_point + "/api", :method => :get, :headers => @@headers, :username => @username, :password => password)
        begin
          begin
            response = request.execute
            result = JSON.parse(response)
            @links = send(request)
          rescue RestClient::ExceptionWithResponse => e
            puts e.response
          end
        rescue Exception => e
          raise ResourceAccessException.new("Resource could not be accessed:#{e.message}")
        end
      end

      def add_domain(namespace, ssh)
        url = @@end_point + @links['ADD_DOMAIN']['href']
        method =  @links['ADD_DOMAIN']['method']
        payload = {:namespace => namespace, :ssh => ssh}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      def domains
        url = @@end_point + @links['LIST_DOMAINS']['href']
        method =  @links['LIST_DOMAINS']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      def find_domain(namespace)
        filtered = Array.new
        domains.each do |domain|
        #TODO do a regex caomparison
          if domain.namespace == namespace
          filtered.push(domain)
          end
        end
        return filtered
      end

      def find_application(name)
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

      def cartridges
        url = @@end_point + @links['LIST_CARTRIDGES']['href']
        method =  @links['LIST_CARTRIDGES']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      def find_cartridge(name)
        filtered = Array.new
        cartridges.each do |cart|
        #TODO do a regex caomparison
          if cart.name == name
          filtered.push(cart)
          end
        end
        return filtered
      end

      def user
        url = @@end_point + @links['GET_USER']['href']
        method =  @links['GET_USER']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      def logout
        #TODO
      end
      alias :close :logout
    end

  end
end