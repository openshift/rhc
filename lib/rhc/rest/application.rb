require 'uri'
require 'rhc/rest/base'

module RHC
  module Rest
    class Application < Base
      include Rest

      define_attr :domain_id, :name, :creation_time, :uuid, :aliases,
                  :git_url, :app_url, :gear_profile, :framework,
                  :scalable, :health_check_path, :embedded, :gear_count,
                  :ssh_url, :building_app
      alias_method :domain_name, :domain_id

      # Query helper to say consistent with cartridge
      def scalable?
        scalable
      end

      def scalable_carts
        return [] unless scalable?
        carts = cartridges.select(&:scalable?)
        scales_with = carts.map(&:scales_with)
        carts.delete_if{|x| scales_with.include?(x.name)}
      end

      def add_cartridge(name, timeout=nil)
        debug "Adding cartridge #{name}"
        @cartridges = nil
        rest_method "ADD_CARTRIDGE", {:name => name}, timeout
      end

      def cartridges
        debug "Getting all cartridges for application #{name}"
        @cartridges ||= rest_method "LIST_CARTRIDGES"
      end

      def gear_groups
        debug "Getting all gear groups for application #{name}"
        rest_method "GET_GEAR_GROUPS"
      end

      def tidy
        debug "Starting application #{name}"
        rest_method 'TIDY', :event => "tidy"
      end

      def start
        debug "Starting application #{name}"
        rest_method 'START', :event => "start"
      end

      def stop(force=false)
        debug "Stopping application #{name} force-#{force}"

        if force
          payload = {:event=> "force-stop"}
        else
          payload = {:event=> "stop"}
        end

        rest_method "STOP", payload
      end

      def restart
        debug "Restarting application #{name}"
        rest_method "RESTART", :event => "restart"
      end

      def destroy
        debug "Deleting application #{name}"
        rest_method "DELETE"
      end
      alias :delete :destroy

      def reload
        debug "Reload application #{name}"
        rest_method "RELOAD", :event => "reload"
      end

      def threaddump
        debug "Running thread dump for #{name}"
        rest_method "THREAD_DUMP", :event => "thread-dump"
      end

      def add_alias(app_alias)
        debug "Running add_alias for #{name}"
        rest_method "ADD_ALIAS", :event => "add-alias", :alias => app_alias
      end

      def remove_alias(app_alias)
        debug "Running add_alias for #{name}"
        rest_method "REMOVE_ALIAS", :event => "remove-alias", :alias => app_alias
      end

      #Find Cartridge by name
      def find_cartridge(sought, options={})
        debug "Finding cartridge #{sought} in app #{name}"

        type = options[:type]

        cartridges.each { |cart| return cart if cart.name == sought and (type.nil? or cart.type == type) }

        suggested_msg = ""
        valid_cartridges = cartridges.select {|c| type.nil? or c.type == type}
        unless valid_cartridges.empty?
          suggested_msg = "\n\nValid cartridges:"
          valid_cartridges.each { |cart| suggested_msg += "\n#{cart.name}" }
        end
        raise RHC::CartridgeNotFoundException.new("Cartridge #{sought} can't be found in application #{name}.#{suggested_msg}")
      end

      #Find Cartridges by name or regex
      def find_cartridges(name, options={})
        if name.is_a?(Hash)
          options = name
          name = options[:name]
        end

        type = options[:type]
        regex = options[:regex]
        debug "Finding cartridge #{name || regex} in app #{@name}"

        filtered = Array.new
        cartridges.each do |cart|
          if regex
            filtered.push(cart) if cart.name.match(regex) and (type.nil? or cart.type == type)
          else
            filtered.push(cart) if cart.name == name and (type.nil? or cart.type == type)
          end
        end
        filtered
      end

      def host
        @host ||= URI(app_url).host
      end

      def ssh_string
        uri = URI(ssh_url)
        "#{uri.user}@#{uri.host}"
      end

      def <=>(other)
        c = name <=> other.name
        return c unless c == 0
        domain_id <=> other.domain_id
      end
    end
  end
end
