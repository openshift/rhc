
module Rhc
  module Rest
    class Application
      include Rest
      attr_reader :domain_id, :name, :creation_time, :uuid, :aliases, :server_identity
      def initialize(args)
        @domain_id = args[:domain_id] || args["domain_id"]
        @name = args[:name] || args["name"]
        @creation_time = args[:creation_time] || args["creation_time"]
        @uuid = args[:uuid] || args["uuid"]
        @aliases = args[:aliases] || args["aliases"]
        @server_identity = args[:server_identity] || args["server_identity"]
        @links = args[:links] || args["links"]
      end

      #Add Cartridge
      def add_cartridge(name)
        logger.debug "Adding cartridge #{name}"
        url = @@end_point + @links['ADD_CARTRIDGE']['href']
        method =  @links['ADD_CARTRIDGE']['method']
        payload = {:name => name}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Get all Cartridge for this applications
      def cartridges
        logger.debug "Getting all cartridges for application #{self.name}"
        url = @@end_point + @links['LIST_CARTRIDGES']['href']
        method =  @links['LIST_CARTRIDGES']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end

      #Start Application
      def start
        logger.debug "Starting application #{self.name}"
        url = @@end_point + @links['START']['href']
        method =  @links['START']['method']
        payload = {:event=> "start"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Stop  Application
      def stop(force=false)
        logger.debug "Stopping application #{self.name} force-#{force}"
        url = @@end_point + @links['STOP']['href']
        method =  @links['STOP']['method']
        if force
          payload = {:event=> "force-stop"}
        else
          payload = {:event=> "stop"}
        end
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Restart Application
      def restart
        logger.debug "Restarting application #{self.name}"
        url = @@end_point + @links['RESTART']['href']
        method =  @links['RESTART']['method']
        payload = {:event=> "restart"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Delete Application
      def destroy
        logger.debug "Deleting application #{self.name}"
        url = @@end_point + @links['DELETE']['href']
        method =  @links['DELETE']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end
      alias :delete :destroy
    end
  end
end
