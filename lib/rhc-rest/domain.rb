module Rhc
  module Rest
    class Domain
      include Rest
      attr_reader :id
      def initialize(args)
        @id = args[:id] || args["id"]
        @links = args[:links] || args["links"]
      end
      
      def get_domain
        logger.debug "Getting domain #{self.id}" if @mydebug
        url = @links['GET_DOMAIN']['href']
        method =  @links['GET_DOMAIN']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return request(request, 3)
      end

      #Add Application to this domain
      # options
      # cartrdige
      # template
      # scale
      # node_profile
      def add_application(name, options)
        logger.debug "Adding application #{name} to domain #{self.id}" if @mydebug
        url = @links['ADD_APPLICATION']['href']
        method =  @links['ADD_APPLICATION']['method']
        payload = {:name => name}
        options.each do |key, value|
          payload[key] = value
        end
        timeout = nil
        if options[:scale]
          timeout = 300 # 5 minute timeout for scalable app
        end
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload, :timeout => timeout)
        return request(request)
      end

      #Get all Application for this domain
      def applications
        logger.debug "Getting all applications for domain #{self.id}" if @mydebug
        url = @links['LIST_APPLICATIONS']['href']
        method =  @links['LIST_APPLICATIONS']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return request(request, 3)
      end

      #Update Domain
      def update(new_id)
        logger.debug "Updating domain #{self.id} to #{new_id}" if @mydebug
        url = @links['UPDATE']['href']
        method =  @links['UPDATE']['method']
        payload = {:id => new_id}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end
      alias :save :update

      #Delete Domain
      def destroy(force=false)
        logger.debug "Deleting domain #{self.id}" if @mydebug
        url = @links['DELETE']['href']
        method =  @links['DELETE']['method']
        payload = {:force => force}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        begin
          return request(request)
        rescue ConnectionException => e
          #see if domain was deleted
          retries = 0
          begin
            until retries == 5 do
              sleep retries*5
              get_domain
              retries += 1
            end
          rescue ResourceNotFoundException => e
            #domain was deleted
            return
          end
          raise ResourceAccessException.new("Failed to delete domain: #{self.id}")
        end
      end
      alias :delete :destroy
    end
  end
end
