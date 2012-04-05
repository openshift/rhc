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
        url = @@end_point + @links['START']['href']
        method =  @links['START']['method']
        payload = {:event=> "start"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Stop Cartridge
      def stop()
        logger.debug "Stopping cartridge #{self.name}" if @mydebug
        url = @@end_point + @links['STOP']['href']
        method =  @links['STOP']['method']
        payload = {:event=> "stop"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Restart Cartridge
      def restart
        logger.debug "Restarting cartridge #{self.name}" if @mydebug
        url = @@end_point + @links['RESTART']['href']
        method =  @links['RESTART']['method']
        payload = {:event=> "restart"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Reload Cartridge
      def reload
        logger.debug "Reloading cartridge #{self.name}" if @mydebug
        url = @@end_point + @links['RESTART']['href']
        method =  @links['RESTART']['method']
        payload = {:event=> "reload"}
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return send(request)
      end

      #Delete Cartridge
      def destroy
        logger.debug "Deleting cartridge #{self.name}" if @mydebug
        url = @@end_point + @links['DELETE']['href']
        method =  @links['DELETE']['method']
        request = RestClient::Request.new(:url => url, :method => method, :headers => @@headers)
        return send(request)
      end
      alias :delete :destroy
      alias :delete :destroy
    end
  end
end
