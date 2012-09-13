require 'uri'

module RHC
  module Rest
    class Application
      include Rest
      attr_reader :domain_id, :name, :creation_time, :uuid, :aliases, :git_url, :app_url, :gear_profile, :framework,
      :scalable, :health_check_path, :embedded, :gear_count, :ssh_url, :scale_min, :scale_max
      def initialize(args)
        #logger.debug args
        @domain_id = args[:domain_id] || args["domain_id"]
        @name = args[:name] || args["name"]
        @creation_time = args[:creation_time] || args["creation_time"]
        @uuid = args[:uuid] || args["uuid"]
        @aliases = args[:aliases] || args["aliases"]
        @git_url = args[:git_url] || args["git_url"]
        @app_url = args[:app_url] || args["app_url"]
        @gear_profile = args[:gear_profile] || args["gear_profile"]
        @framework = args[:framework] || args["framework"]
        @scalable = args[:scalable] || args["scalable"]
        @health_check_path = args[:health_check_path] || args["health_check_path"]
        @embedded = args[:embedded] || args["embedded"]
        @gear_count = args[:gear_count] || args["gear_count"]
        @ssh_url = args[:ssh_url] || args["ssh_url"]
        @scale_min = args[:scale_min] || args["scale_min"]
        @scale_max = args[:scale_max] || args["scale_max"]
        @links = args[:links] || args["links"]
      end

      def host
        @host ||= URI(@app_url).host
      end

      #Add Cartridge
      def add_cartridge(name)
        logger.debug "Adding cartridge #{name}" if @mydebug
        url = @links['ADD_CARTRIDGE']['href']
        method =  @links['ADD_CARTRIDGE']['method']
        payload = {:name => name}
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Get all Cartridge for this applications
      def cartridges
        logger.debug "Getting all cartridges for application #{self.name}" if @mydebug
        url = @links['LIST_CARTRIDGES']['href']
        method =  @links['LIST_CARTRIDGES']['method']
        request = new_request(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end

      #Find Cartridge by name
      def find_cartridge(name, options={})
        logger.debug "Finding cartridge #{name} in app #{@name}" if @mydebug

        type = options[:type]

        cartridges.each { |cart| return cart if cart.name == name and (type.nil? or cart.type == type) }

        suggested_msg = ""
        unless cartridges.empty?
          suggested_msg = "\n\nValid cartridges:"
          cartridges.each { |cart| suggested_msg += "\n#{cart.name}" if type.nil? or cart.type == type }
        end
        raise RHC::CartridgeNotFoundException.new("Cartridge #{name} can't be found in application #{@name}.#{suggested_msg}")
      end

      #Start Application
      def start
        logger.debug "Starting application #{self.name}" if @mydebug
        url = @links['START']['href']
        method =  @links['START']['method']
        payload = {:event=> "start"}
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Stop  Application
      def stop(force=false)
        logger.debug "Stopping application #{self.name} force-#{force}" if @mydebug
        url = @links['STOP']['href']
        method =  @links['STOP']['method']
        if force
          payload = {:event=> "force-stop"}
        else
          payload = {:event=> "stop"}
        end
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Restart Application
      def restart
        logger.debug "Restarting application #{self.name}" if @mydebug
        url = @links['RESTART']['href']
        method =  @links['RESTART']['method']
        payload = {:event=> "restart"}
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Delete Application
      def destroy
        logger.debug "Deleting application #{self.name}" if @mydebug
        url = @links['DELETE']['href']
        method =  @links['DELETE']['method']
        request = new_request(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end

      #Thread dump
      def threaddump
        logger.debug "Running thread dump for #{self.name}" if @mydebug
        url = @links['THREAD_DUMP']['href']
        method =  @links['THREAD_DUMP']['method']
        payload = {:event => 'thread-dump'}
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)

      end
      alias :delete :destroy
    end
  end
end
