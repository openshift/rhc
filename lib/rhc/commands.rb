require 'commander'
require 'rhc/helpers'

module RHC
  module Commands
    class CommandHelpBindings
      def initialize(command, instance_commands, global_options)
        @command = command
        @actions = instance_commands.collect do |ic|
          m = /^#{command.name} ([^ ]+)/.match(ic[0])
          # if we have a match and it is not an alias then we can use it
          m and ic[0] == ic[1].name ? {:name => m[1], :summary => ic[1].summary || ""} : nil
        end
        @actions.compact!
        @global_options = global_options
      end
    end
    class Runner < Commander::Runner
      # regex fix from git - match on word boundries
      def valid_command_names_from *args
        arg_string = args.delete_if { |value| value =~ /^-/ }.join ' '
        commands.keys.find_all { |name| name if /^#{name}\b/.match arg_string }
      end

      # override so we can do our own error handling
      def run!
        trace = false
        require_program :version, :description
        trap('INT') { abort program(:int_message) } if program(:int_message)
        trap('INT') { program(:int_block).call } if program(:int_block)
        global_option('-h', '--help', 'Display help documentation') do
          args = @args - %w[-h --help]
          command(:help).run(*args)
          return
        end
        global_option('-v', '--version', 'Display version information') { say version; return }
        global_option('-t', '--trace', 'Display backtrace when an error occurs') { trace = true }
        parse_global_options
        remove_global_options options, @args

        # if help is last arg run as if --help was passed in
        if @args[-1] == "help"
          args = @args - ["help"]
          command(:help).run(*args)
          return
        end

        unless trace
          begin
            run_active_command
          rescue InvalidCommandError => e
            usage = RHC::UsageHelpFormatter.new(self).render
            i = @args.find_index { |a| a.start_with?('-') } || @args.length
            abort "The command 'rhc #{@args[0,i].join(' ')}' is not recognized.\n#{usage}"
          rescue \
            ArgumentError,
            OptionParser::InvalidOption,
            OptionParser::InvalidArgument,
            OptionParser::MissingArgument => e

            help_bindings = CommandHelpBindings.new(active_command, commands, Commander::Runner.instance.options)
            usage = RHC::UsageHelpFormatter.new(self).render_command(help_bindings)
            say "#{e}\n#{usage}"
            1
          rescue RHC::Rest::Exception, RHC::Exception => e
            RHC::Helpers.results { say e.message }
            e.code.nil? ? 128 : e.code
          rescue => e
            RHC::Helpers.results { say "error: #{e} Use --trace to view backtrace." }
            128
          end
        else
          run_active_command
        end
      end

      def create_default_commands
        command :help do |c|
          c.syntax = 'rhc help <command>'
          c.description = 'Display global or <command> help documentation.'
          c.when_called do |args, options|
            if args.empty?
              say help_formatter.render
            else
              command = command args.join(' ')
              begin
                require_valid_command command
              rescue InvalidCommandError => e
                abort "#{e}"
              end

              help_bindings = CommandHelpBindings.new command, commands, Commander::Runner.instance.options
              say help_formatter.render_command help_bindings
            end
          end
        end
      end
    end

    def self.load
      Dir[File.join(File.dirname(__FILE__), "commands", "*.rb")].each do |file|
        require file
      end
      self
    end
    def self.add(opts)
      commands[opts[:name]] = opts
    end
    def self.global_option(switches, description)
      global_options << [switches, description].flatten(1)
    end

    def self.global_config_setup(options)
      RHC::Config.set_opts_config(options.config) if options.config
      RHC::Config.password = options.password if options.password
      RHC::Config.opts_login = options.rhlogin if options.rhlogin
      RHC::Config.noprompt(options.noprompt) if options.noprompt
      RHC::Config
    end

    def self.needs_configuration!(cmd, config)
      # check to see if we need to run wizard
      if not cmd.class.suppress_wizard?
        w = RHC::Wizard.new config
        return w.run if w.needs_configuration?
      end
      false
    end

    def self.to_commander(instance=Commander::Runner.instance)
      global_options.each{ |args| instance.global_option *args }
      commands.each_pair do |name, opts|
        instance.command name do |c|
          c.description = opts[:description]
          c.summary = opts[:summary]
          c.syntax = opts[:syntax]

          options_metadata = opts[:options]||[]
          options_metadata.each do |o|
            option_data = [o[:switches], o[:description]].flatten(1)
            c.option *option_data
            o[:arg] = Runner.switch_to_sym(o[:switches].last)
          end
          args_metadata = opts[:args] || []
          (args_metadata).each do |arg_meta|
            arg_switches = arg_meta[:switches]
            unless arg_switches.nil? or arg_switches.empty?
              arg_switches << arg_meta[:description]
              c.option *arg_switches
            end
          end

          c.when_called do |args, options|
            config = global_config_setup options
            cmd = opts[:class].new c
            cmd.options = options
            cmd.config = config
            filled_args = cmd.validate_args_and_options args_metadata, options_metadata, args
            needs_configuration! cmd, config
            cmd.send opts[:method], *filled_args
          end

          unless opts[:aliases].nil?
            opts[:aliases].each do |a, root_command|
              alias_cmd = a
              unless root_command
                # prepend the current resource
                alias_components = name.split(" ")
                alias_components[-1] = a
                alias_cmd = alias_components.join(' ')
              end
              instance.alias_command  "#{alias_cmd}", :"#{name}"
            end
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
  end
end
