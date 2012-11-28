require 'rhc/rest/base'
require 'pp'

module RHC
  module Rest
    class Cartridge < Base
      define_attr :type, :name, :display_name, :properties, :gear_profile, :status_messages, :scales_to, :scales_from, :scales_with, :current_scale, :supported_scales_to, :supported_scales_from, :tags

      def scalable?
        supported_scales_to != supported_scales_from
      end

      def display_name
        attribute(:display_name) || name
      end

      def scaling
        {
          :current_scale => current_scale,
          :scales_from => scales_from,
          :scales_to => scales_to,
          :gear_profile => gear_profile
        } if scalable?
      end

      def property(type, key)
        key, type = key.to_s, type.to_s
        properties.select{ |p| p['type'] == type }.find{ |p| p['name'] == key }
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

      def connection_info
        info = property(:cart_data, :connection_url) || property(:cart_data, :job_url) || property(:cart_data, :monitoring_url)
        info ? (info["value"] || '').rstrip : nil
      end

      def <=>(other)
        name <=> other.name
      end
    end
  end
end
