require 'rhc/rest/base'

module RHC
  module Rest
    class Cartridge < Base
      attr_reader :type, :name, :properties, :status_messages
      def initialize(args, use_debug=false)
        @properties = {}
        props = args[:properties] || args["properties"] || []
        props.each do |p|
          category = @properties[:"#{p['type']}"] || {}
          category[:"#{p['name']}"] = p
          @properties[:"#{p['type']}"] = category
        end

        super
      end

      def property(category, key)
         category = properties[category]
         category ? category[key] : nil
      end

      def status
        debug "Getting cartridge #{name}'s status"
        result = rest_method "GET", :include => "status_messages"
        result.status_messages
      end

      def start
        debug "Starting cartridge #{name}"
        rest_method "START", :event => "start"
      end

      def stop()
        debug "Stopping cartridge #{name}"
        rest_method "STOP", :event => "stop"
      end

      def restart
        debug "Restarting cartridge #{name}"
        rest_method "RESTART", :event => "restart"
      end

      def reload
        debug "Reloading cartridge #{name}"
        rest_method "RESTART", :event => "reload"
      end

      def destroy
        debug "Deleting cartridge #{name}"
        rest_method "DELETE"
      end
      alias :delete :destroy
    end
  end
end
