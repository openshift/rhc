module Rhc
  module Rest
    class Domain
      include Rest
      attr_reader :namespace
      def initialize(args)
        @namespace = args[:namespace] || args["namespace"]
        @links = args[:links] || args["links"]
      end

      #Add Application to this domain
      def add_application(name, cartridge, scale=false)
        logger.debug "Adding application #{name} to domain #{self.namespace}"
        url = @@end_point + @links['ADD_APPLICATION']['href']
        method =  @links['ADD_APPLICATION']['method']
        payload = {:name => name, :cartridge => cartridge}
        if scale
          payload[:scale] = true
        end
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Get all Application for this domain
      def applications
        logger.debug "Getting all applications for domain #{self.namespace}"
        url = @@end_point + @links['LIST_APPLICATIONS']['href']
        method =  @links['LIST_APPLICATIONS']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      #Update Domain
      def update(new_namespace)
        logger.debug "Updating domain #{self.namespace} to #{new_namespace}"
        url = @@end_point + @links['UPDATE']['href']
        method =  @links['UPDATE']['method']
        payload = {:namespace => new_namespace}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end
      alias :save :update

      #Delete Domain
      def destroy(force=false)
        logger.debug "Deleting domain #{self.namespace}"
        url = @@end_point + @links['DELETE']['href']
        method =  @links['DELETE']['method']
        payload = {:force => force}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end
      alias :delete :destroy
    end
  end
end
