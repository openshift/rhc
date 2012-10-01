require 'uri'
require 'rhc/rest/base'

module RHC
  module Rest
    class Application < Base
      include Rest
      attr_reader :domain_id, :name, :creation_time, :uuid, :aliases,
                  :git_url, :app_url, :gear_profile, :framework,
                  :scalable, :health_check_path, :embedded, :gear_count,
                  :ssh_url, :scale_min, :scale_max

      def add_cartridge(name)
        debug "Adding cartridge #{name}"
        rest_method "ADD_CARTRIDGE", :name => name
      end

      def cartridges
        debug "Getting all cartridges for application #{name}"
        rest_method "LIST_CARTRIDGES"
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
      def find_cartridge(name, options={})
        debug "Finding cartridge #{name} in app #{self.name}"

        type = options[:type]

        cartridges.each { |cart| return cart if cart.name == name and (type.nil? or cart.type == type) }

        suggested_msg = ""
        unless cartridges.empty?
          suggested_msg = "\n\nValid cartridges:"
          cartridges.each { |cart| suggested_msg += "\n#{cart.name}" if type.nil? or cart.type == type }
        end
        raise RHC::CartridgeNotFoundException.new("Cartridge #{name} can't be found in application #{@name}.#{suggested_msg}")
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

      #Application log file tailing
      def tail(options)
        debug "Tail in progress for #{name}"

        file_glob = options.files ? options.files : "#{name}/logs/*"
        remote_cmd = "tail#{options.opts ? ' --opts ' + Base64::encode64(options.opts).chomp : ''} #{file_glob}"
        ssh_cmd = "ssh -t #{uuid}@#{host} '#{remote_cmd}'"
        begin
          #Use ssh -t to tail the logs
          debug ssh_cmd
          ssh_ruby(host, uuid, remote_cmd)
        rescue SocketError => e
          msg <<MESSAGE
Could not connect: #{e.message}
You can try to run this manually if you have ssh installed:
#{ssh_cmd}

MESSAGE
          debug "DEBUG: #{e.debug}\n"
          raise e
        end
      end
    end
  end
end
