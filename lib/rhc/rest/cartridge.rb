require 'rhc/rest/base'

module RHC
  module Rest
    class Cartridge < Base
      attr_reader :type, :name, :display_name, :properties, :status_messages, :scales_to, :scales_from, :scales_with, :current_scale, :base_gear_storage, :additional_gear_storage
      def initialize(args, use_debug=false)
        @properties = {}
        props = args[:properties] || args["properties"] || []
        props.each do |p|
          category = @properties[:"#{p['type']}"] || {}
          category[:"#{p['name']}"] = p
          @properties[:"#{p['type']}"] = category
        end

        # Make sure that additional gear storage is an integer
        # TODO:  This should probably be fixed in the broker
        args['additional_gear_storage'] = args['additional_gear_storage'].to_i rescue 0

        super
      end

      def scalable?
        [scales_to,scales_from].map{|x| x > 1 || x == -1}.inject(:|)
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

      def set_scales(values)
        values.delete_if{|k,v| v.nil? }
        debug "Setting scales = %s" % values.map{|k,v| "#{k}: #{v}"}.join(" ")
        rest_method "UPDATE", values
      end

      def set_storage(values)
        debug "Setting additional storage: #{values[:additional_gear_storage]}GB"
        rest_method "UPDATE", values
      end

      def connection_info
        info = property(:cart_data, :connection_url) || property(:cart_data, :job_url) || property(:cart_data, :monitoring_url)
        info ? (info["value"] || '').rstrip : nil
      end
    end
  end
end
