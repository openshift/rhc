module RHC
  module Rest
    class Cartridge
      include Rest
      attr_reader :type, :name, :properties
      def initialize(args)
        @name = args[:name] || args["name"]
        @type = args[:type] || args["type"]
        @links = args[:links] || args["links"]
        @properties = {}
        props = args[:properties] || args["properties"] || []
        props.each do |p|
          category = @properties[:"#{p['type']}"] || {}
          category[:"#{p['name']}"] = p
          @properties[:"#{p['type']}"] = category
        end
      end

      def property(category, key)
         category = properties[category]
         category ? category[key] : nil
      end

      #Start Cartridge
      def start
        logger.debug "Starting cartridge #{self.name}" if @mydebug
        url = @links['START']['href']
        method =  @links['START']['method']
        payload = {:event=> "start"}
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Stop Cartridge
      def stop()
        logger.debug "Stopping cartridge #{self.name}" if @mydebug
        url = @links['STOP']['href']
        method =  @links['STOP']['method']
        payload = {:event=> "stop"}
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Restart Cartridge
      def restart
        logger.debug "Restarting cartridge #{self.name}" if @mydebug
        url = @links['RESTART']['href']
        method =  @links['RESTART']['method']
        payload = {:event=> "restart"}
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Reload Cartridge
      def reload
        logger.debug "Reloading cartridge #{self.name}" if @mydebug
        url = @links['RESTART']['href']
        method =  @links['RESTART']['method']
        payload = {:event=> "reload"}
        request = new_request(:url => url, :method => method, :headers => @@headers, :payload => payload)
        return request(request)
      end

      #Delete Cartridge
      def destroy
        logger.debug "Deleting cartridge #{self.name}" if @mydebug
        url = @links['DELETE']['href']
        method =  @links['DELETE']['method']
        request = new_request(:url => url, :method => method, :headers => @@headers)
        return request(request)
      end
      alias :delete :destroy
      alias :delete :destroy
    end
  end
end
