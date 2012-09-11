module RHC
  module Rest
    class Domain
      include Rest
      attr_reader :id
      def initialize(args)
        @id = args[:id] || args["id"]
        @links = args[:links] || args["links"]
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
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload, :timeout => timeout)
        return request(request)
      end

      #Get all Application for this domain
      def applications
        logger.debug "Getting all applications for domain #{self.id}" if @mydebug
        url = @links['LIST_APPLICATIONS']['href']
        method =  @links['LIST_APPLICATIONS']['method']
        request = new_request(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end

      def find_application(name, options={})
        if name.is_a?(Hash)
          options = name.merge(options)
          name = options[:name]
        end
        framework = options[:framework]

        logger.debug "Finding application :name => #{name}, :framework => #{framework}" if @mydebug
        applications.each do |app|
          return app if (name.nil? or app.name == name) and (framework.nil? or app.framework == framework)
        end

        raise RHC::ApplicationNotFoundException.new("Application #{name} does not exist")
      end

      #Update Domain
      def update(new_id)
        logger.debug "Updating domain #{self.id} to #{new_id}" if @mydebug
        url = @links['UPDATE']['href']
        method =  @links['UPDATE']['method']
        payload = {:id => new_id}
        # 5 minute timeout as this may take time if there are a lot of apps
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload, :timeout=> 300)
        return request(request)
      end
      alias :save :update

      #Delete Domain
      def destroy(force=false)
        logger.debug "Deleting domain #{self.id}" if @mydebug
        url = @links['DELETE']['href']
        method =  @links['DELETE']['method']
        payload = {:force => force}
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end
      alias :delete :destroy
    end
  end
end
