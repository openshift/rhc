require 'commander'
require 'rhc/helpers'

module RHC
  module Commands
    def self.load
      Dir[File.join(File.dirname(__FILE__), "commands", "*.rb")].each do |file|
        require file
      end
      self
    end
    def self.add(opts)
      commands[opts[:name]] = opts
    end
    def self.global_option(*args, &block)
      global_options << [args, block]
    end

    def self.global_config_setup(options)
      RHC::Config.set_opts_config(options.config) if options.config
      RHC::Config.password = options.password if options.password
      RHC::Config.opts_login = options.rhlogin if options.rhlogin
      RHC::Config
    end

    def self.deprecated?
      command_name = Commander::Runner.instance.command_name_from_args
      command = Commander::Runner.instance.active_command

      if deprecated[command_name]
        deprecated_cmd("rhc #{command.name}")
      end
    end

    def self.needs_configuration!(cmd, options, config)
      if not (cmd.class.suppress_wizard? or
              options.noprompt or
              options.help or
              config.has_local_config? or
              config.has_opts_config?)
        RHC::Wizard.new(config).run
      end
    end

    def self.to_commander(instance=Commander::Runner.instance)
      global_options.each do |args, block|
        opts = (args.pop if Hash === args.last) || {}
        option = instance.global_option(*args, &block).last
        option.merge!(opts)
      end
      commands.each_pair do |name, opts|
        instance.command name do |c|
          c.description = opts[:description]
          c.summary = opts[:summary]
          c.syntax = opts[:syntax]

          (options_metadata = opts[:options] || []).each do |o|
            option_data = [o[:switches], o[:description]].flatten(1)
            c.option *option_data
            o[:arg] = Commander::Runner.switch_to_sym(o[:switches].last)
          end

          args_metadata = opts[:args] || []
          args_metadata.each do |arg_meta|
            arg_switches = arg_meta[:switches]
            unless arg_switches.nil? or arg_switches.empty?
              arg_switches << arg_meta[:description]
              c.option *arg_switches
            end
          end

          unless opts[:aliases].nil?
            opts[:aliases].each do |a|
              alias_cmd = a[:action]

              unless a[:root_command]
                # prepend the current resource
                alias_components = name.split(" ")
                alias_components[-1] = a[:action]
                alias_cmd = alias_components.join(' ')
              end

              deprecated[alias_cmd] = true if a[:deprecated]
              instance.alias_command "#{alias_cmd}", :"#{name}"
            end
          end

          c.when_called do |args, options|
            config = global_config_setup(options)
            deprecated?

            cmd = opts[:class].new
            cmd.options = options
            cmd.config = config

            filled_args = cmd.validate_args_and_options(args_metadata, options_metadata, args)

            needs_configuration!(cmd, options, config)
            cmd.send(opts[:method], *filled_args)
          end
        end
      end
      self
    end

    protected
      def self.commands
        @commands ||= {}
      end
      def self.global_options
        @options ||= []
      end
      def self.deprecated
        @deprecated ||= {}
      end
  end
end
