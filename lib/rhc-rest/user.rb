module Rhc
  module Rest
    class User
      include Rest
      attr_reader :login
      def initialize(args)
        @login = args[:login] || args["login"]
        @links = args[:links] || args["links"]
      end

      #Add Key for this user
      def add_key(name, content, type)
        url = @links['ADD_KEY']['href']
        method =  @links['ADD_KEY']['method']
        payload = {:name => name, :type => type, :content => content}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Get all Key for this user
      def keys
        url = @links['LIST_KEYS']['href']
        method =  @links['LIST_KEYS']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end

      #Find Key by name
      def find_key(name)
        filtered = Array.new
        keys.each do |key|
        #TODO do a regex caomparison
          if key.name == name
          filtered.push(key)
          end
        end
        return filtered
      end
    end
  end
end
