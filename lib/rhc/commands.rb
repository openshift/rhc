require 'commander'

module RHC
  module Commands
    class CommandHelpBindings
      def initialize(command, instance_commands, global_options)
        @command = command
        @actions = instance_commands.collect do |ic|
          m = /^#{command.name} ([^ ]+)/.match(ic[0])
          m ? {:name => m[1], :summary => ic[1].summary || ""} : nil
        end
        @actions.compact!
        @global_options = global_options
      end
    end
    class Runner < Commander::Runner
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
            abort "Invalid rhc resource: #{@args[0]}. Use --trace to view backtrace\n#{usage}"
          rescue \
            ArgumentError,
            OptionParser::InvalidOption,
            OptionParser::InvalidArgument,
            OptionParser::MissingArgument => e

            help_bindings = CommandHelpBindings.new(active_command, commands, Commander::Runner.instance.options)
            usage = RHC::UsageHelpFormatter.new(self).render_command(help_bindings)
            say "#{e}. Use --trace to view backtrace.\n#{usage}"
            1
          rescue Rhc::Rest::BaseException => e
            say "#{e}. Use --trace to view backtrace."
            e.code.nil? ? 128 : e.code
          rescue Exception => e
            say "error: #{e}. Use --trace to view backtrace."
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
    def self.validate_command(c, args, options, args_metadata)
      # check to see if an arg's option was set
      raise ArgumentError.new("Invalid arguments") if args.length > args_metadata.length
      args_metadata.each_with_index do |arg_meta, i|
        switch = arg_meta[:switches]
        value = options.__hash__[arg_meta[:name]]
        unless value.nil?
          raise ArgumentError.new("#{arg_meta[:name]} specified twice on the command line and as a #{switch[0]} switch") unless args.length == i
          # add the option as an argument
          args << value
        end
      end
    end
    def self.to_commander(instance=Commander::Runner.instance)
      global_options.each{ |args| instance.global_option *args }
      commands.each_pair do |name, opts|
        instance.command name do |c|
          c.description = opts[:description]
          c.summary = opts[:summary]
          c.syntax = opts[:syntax]

          (opts[:options]||[]).each { |o| c.option *o }
          args_metadata = opts[:args] || []
          (args_metadata).each do |arg_meta|
            arg_switches = arg_meta[:switches]
            arg_switches << arg_meta[:description]
            c.option *arg_switches unless arg_switches.nil?
          end

          c.when_called do |args, options|
            validate_command(c, args, options, args_metadata)
            cmd = opts[:class].new(c, args, options)
            cmd.run_wizard?
            cmd.send(opts[:method], *args)
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
