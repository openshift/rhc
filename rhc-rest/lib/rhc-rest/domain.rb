module Rhc
  module Rest
    class Domain
      include Rest
      attr_reader :namespace
      def initialize(args)
        @namespace = args[:namespace] || args["namespace"]
        @links = args[:links] || args["links"]
      end

      def add_application(name, cartridge)
        url = @@end_point + @links['ADD_APPLICATION']['href']
        method =  @links['ADD_APPLICATION']['method']
        payload = {:name => name, :cartridge => cartridge}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      def applications
        url = @@end_point + @links['LIST_APPLICATIONS']['href']
        method =  @links['LIST_APPLICATIONS']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      def create(namespace, ssh)
        url = @@end_point + @links['CREATE']['href']
        method =  @links['CREATE']['method']
        payload = {:namespace => namespace, :ssh => ssh}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      def update(args)
        url = @@end_point + @links['UPDATE']['href']
        method =  @links['UPDATE']['method']
        payload = args
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end
      alias :save :update

      def destroy(force)
        url = @@end_point + @links['DELETE']['href']
        method =  @links['DELETE']['method']
        payload[:force] = force if force
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end
      alias :delete :destroy
    end
  end
end
