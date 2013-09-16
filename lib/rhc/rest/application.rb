require 'uri'

module RHC
  module Rest
    class Application < Base
      include Membership

      define_attr :domain_id, :name, :creation_time, :uuid,
                  :git_url, :app_url, :gear_profile, :framework,
                  :scalable, :health_check_path, :embedded, :gear_count,
                  :ssh_url, :building_app, :cartridges, :initial_git_url
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

      def add_cartridge(cart, options={})
        debug "Adding cartridge #{name}"
        clear_attribute :cartridges
        cart =
          if cart.is_a? String
            {:name => cart}
          elsif cart.respond_to? :[]
            cart
          else
            c = cart.url ? {:url => cart.url} : {:name => cart.name}
            if cart.respond_to?(:environment_variables) && cart.environment_variables.present?
              c[:environment_variables] = cart.environment_variables
            end
            cart = c
          end

        if cart.respond_to?(:[]) and cart[:url] and !has_param?('ADD_CARTRIDGE', 'url')
          raise RHC::Rest::DownloadingCartridgesNotSupported, "The server does not support downloading cartridges."
        end

        rest_method(
          "ADD_CARTRIDGE",
          cart,
          options
        )
      end

      def cartridges
        @cartridges ||=
          unless (carts = attributes['cartridges']).nil?
            carts.map{|x| Cartridge.new(x, client) }
          else
            debug "Getting all cartridges for application #{name}"
            rest_method "LIST_CARTRIDGES"
          end
      end

      def domain
        domain_id
      end

      def gear_info
        { :gear_count => gear_count, :gear_profile => gear_profile } unless gear_count.nil?
      end

      def gear_groups
        debug "Getting all gear groups for application #{name}"
        rest_method "GET_GEAR_GROUPS"
      end

      def gears
        gear_groups.map{ |group| group.gears }.flatten
      end

      def gear_ssh_url(gear_id)
        gear = gears.find{ |g| g['id'] == gear_id }

        raise ArgumentError, "Gear #{gear_id} not found" if gear.nil?
        gear['ssh_url'] or raise NoPerGearOperations
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

      def environment_variables
        debug "Getting all environment variables for application #{name}"
        if supports? "LIST_ENVIRONMENT_VARIABLES"
          rest_method "LIST_ENVIRONMENT_VARIABLES"
        else
          raise RHC::EnvironmentVariablesNotSupportedException.new
        end
      end

      def find_environment_variable(env_var_name)
        find_environment_variables(env_var_name).first
      end

      def find_environment_variables(env_var_names=nil)
        return environment_variables if env_var_names.nil?
        env_var_names = [env_var_names].flatten
        debug "Finding environment variable(s) #{env_var_names.inspect} in app #{@name}"
        env_vars = environment_variables.select { |item| env_var_names.include? item.name }
        raise RHC::EnvironmentVariableNotFoundException.new("Environment variable(s) #{env_var_names.join(', ')} can't be found in application #{name}.") if env_vars.empty?
        env_vars
      end

      # @param [Array<RHC::Rest::EnvironmentVariable>] Array of RHC::Rest::EnvironmentVariable to be set
      def set_environment_variables(env_vars=[])
        debug "Adding environment variable(s) #{env_vars.inspect} for #{name}"
        if supports? "SET_UNSET_ENVIRONMENT_VARIABLES"
          rest_method "SET_UNSET_ENVIRONMENT_VARIABLES", :environment_variables => env_vars.map{|item| item.to_hash}
        else
          raise RHC::EnvironmentVariablesNotSupportedException.new
        end
      end

      # @param [Array<String>] Array of env var names like ['FOO', 'BAR']
      def unset_environment_variables(env_vars=[])
        debug "Removing environment variable(s) #{env_vars.inspect} for #{name}"
        if supports? "SET_UNSET_ENVIRONMENT_VARIABLES"
          rest_method "SET_UNSET_ENVIRONMENT_VARIABLES", :environment_variables => env_vars.map{|item| {:name => item}}
        else
          raise RHC::EnvironmentVariablesNotSupportedException.new
        end
      end

      def add_alias(app_alias)
        debug "Running add_alias for #{name}"
        rest_method "ADD_ALIAS", :event => "add-alias", :alias => app_alias
      end

      def remove_alias(app_alias)
        debug "Running remove_alias for #{name}"
        if (client.api_version_negotiated >= 1.4)
          find_alias(app_alias).destroy
        else
          rest_method "REMOVE_ALIAS", :event => "remove-alias", :alias => app_alias
        end
      end

      def aliases
        debug "Getting all aliases for application #{name}"
        @aliases ||= begin
          aliases = attributes['aliases']
          if aliases.nil? or not aliases.is_a?(Array)
            supports?('LIST_ALIASES') ? rest_method("LIST_ALIASES") : []
          else
            aliases.map do |a|
              Alias.new(a.is_a?(String) ? {'id' => a} : a, client)
            end
          end
        end
      end

      def find_alias(name, options={})
        debug "Finding alias #{name} in app #{@name}"

        if name.is_a?(Hash)
          options = name
          name = options[:name]
        end
        aliases.each { |a| return a if a.is_a?(String) || a.id == name.downcase }
        raise RHC::AliasNotFoundException.new("Alias #{name} can't be found in application #{@name}.")
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
            filtered.push(cart) if cart.name.match(/(?i:#{regex})/) and (type.nil? or cart.type == type)
          else
            filtered.push(cart) if cart.name.downcase == name.downcase and (type.nil? or cart.type == type)
          end
        end
        filtered
      end

      def host
        @host ||= URI.parse(app_url).host rescue nil
      end

      def ssh_string
        RHC::Helpers.ssh_string(ssh_url)
      end

      def <=>(other)
        c = name.downcase <=> other.name.downcase
        return c unless c == 0
        domain_id <=> other.domain_id
      end
    end
  end
end
