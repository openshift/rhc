module RHC
  module Rest
    class Cartridge < Base
      include RHC::CurrencyHelpers

      HIDDEN_TAGS = [:framework, :web_framework, :cartridge].map(&:to_s)

      define_attr :type, :name, :display_name, :properties, :gear_profile, :status_messages, :scales_to, :scales_from, :scales_with,
                  :current_scale, :supported_scales_to, :supported_scales_from, :tags, :description, :collocated_with, :base_gear_storage,
                  :additional_gear_storage, :url, :environment_variables, :gear_size, :automatic_updates,
                  :version, :license, :website, :description

      def scalable?
        supported_scales_to != supported_scales_from
      end

      def custom?
        url.present?
      end

      def only_in_new?
        type == 'standalone'
      end

      def only_in_existing?
        type == 'embedded'
      end

      def automatic_updates?
        v = attribute(:automatic_updates)
        if v.nil?
          v = !(tags.include?('no_updates') || custom?)
        end
        v
      end

      def external?
        tags.include?('external')
      end

      def shares_gears?
        Array(collocated_with).present?
      end
      def collocated_with
        Array(attribute(:collocated_with))
      end

      def tags
        Array(attribute(:tags))
      end

      def gear_storage
        (base_gear_storage + additional_gear_storage) * 1024 * 1024 * 1024
      end

      def additional_gear_storage
        attribute(:additional_gear_storage).to_i rescue 0
      end

      def display_name
        attribute(:display_name) || name || url_basename
      end

      #
      # Use this value when the user should interact with this cart via CLI arguments
      #
      def short_name
        name || url
      end

      def usage_rate?
        rate = usage_rate
        rate && rate > 0.0
      end

      def usage_rate(currency='usd')
        rate = attribute("usage_rate_#{currency}".to_sym)

        if attribute(:usage_rates)
          begin
            rate ||= attribute(:usage_rates)["Rate"][currency]
          rescue
            rate ||= attribute(:usage_rates).inject(0) { |total, rate| total + rate[currency].to_f }
          end
        end

        rate.to_f rescue 0.0
      end

      def usage_rate_desc(locale='en-us', currency='usd')
        if attribute(:usage_rates)
          ur = attribute(:usage_rates)
          val = {
            'currency' => currency_symbol(currency),
            'rate'     => ur["Rate"][currency] || 0.0,
            'scope'    => ur["Scope"] || '',
            'duration' => ur["Duration"] || ''
          }
          desc = ur["Description"]
          desc = desc[locale] if desc.is_a? Hash and desc.key? locale
          begin
            r = desc % val
          rescue
            r = desc.gsub(/%\{[^}]+\}/) { |m| val[m[2...-1]] }
          end
        else
          r = "This gear costs an additional $#{usage_rate} per gear."
        end
        r
      end

      def scaling
        {
          :current_scale => current_scale,
          :scales_from => scales_from,
          :scales_to => scales_to,
          :gear_profile => gear_profile,
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

      def stop
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

      def <=>(other)
        return -1 if other.type == 'standalone' && type != 'standalone'
        return 1  if type == 'standalone' && other.type != 'standalone'
        name <=> other.name
      end

      def url_basename
        uri = URI.parse(url)
        name = uri.fragment
        name = Rack::Utils.parse_nested_query(uri.query)['name'] if name.blank? && uri.query
        name = File.basename(uri.path) if name.blank? && uri.path.present? && uri.path != '/'
        name.presence || url
      rescue
        url
      end

      def self.for_url(url)
        new 'url' => url
      end
    end
  end
end
