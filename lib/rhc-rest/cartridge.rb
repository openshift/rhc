module Rhc
  module Rest
    class Cartridge
      include Rest
      attr_reader :type, :name
      def initialize(args)
        @name = args[:name] || args["name"]
        @type = args[:type] || args["type"]
        @links = args[:links] || args["links"]
      end

      #Start Cartridge
      def start
        logger.debug "Starting cartridge #{self.name}" if @mydebug
        url = @links['START']['href']
        method =  @links['START']['method']
        payload = {:event=> "start"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Stop Cartridge
      def stop()
        logger.debug "Stopping cartridge #{self.name}" if @mydebug
        url = @links['STOP']['href']
        method =  @links['STOP']['method']
        payload = {:event=> "stop"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Restart Cartridge
      def restart
        logger.debug "Restarting cartridge #{self.name}" if @mydebug
        url = @links['RESTART']['href']
        method =  @links['RESTART']['method']
        payload = {:event=> "restart"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Reload Cartridge
      def reload
        logger.debug "Reloading cartridge #{self.name}" if @mydebug
        url = @links['RESTART']['href']
        method =  @links['RESTART']['method']
        payload = {:event=> "reload"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Delete Cartridge
      def destroy
        logger.debug "Deleting cartridge #{self.name}" if @mydebug
        url = @links['DELETE']['href']
        method =  @links['DELETE']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end
      alias :delete :destroy
      alias :delete :destroy
    end
  end
end
