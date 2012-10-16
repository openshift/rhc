module RHC
  class CommandRunner < Commander::Runner
    # regex fix from git - match on word boundries
    def valid_command_names_from *args
      arg_string = args.delete_if { |value| value =~ /^-/ }.join ' '
      commands.keys.find_all { |name| name if /^#{name}\b/.match arg_string }
    end

    def options_parse_trace
      if @args.include? "--trace"
        @args.delete "--trace"
        return true
      end
      false
    end

    def options_parse_version
      if @args.include? "--version" or @args.include? "-v"
        say version
        exit 0
      end
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
      global_option('--timeout seconds', Integer, 'Set the timeout in seconds for network commands') do |value|
        # FIXME: Refactor so we don't have to use a global var here
        $rest_timeout = value
      end

      # remove these because we monkey patch Commands to process all options
      # at once, avoiding conflicts between the global and command options
      # code left here just in case someone compares this with the original
      # commander code
      #parse_global_options
      #remove_global_options options, @args

      # special case --trace because we need to use it in the runner
      trace = options_parse_trace

      # special case --version so it is processed before an invalid command
      options_parse_version

      unless trace
        begin
          run_active_command
        rescue InvalidCommandError => e
          if provided_arguments.empty?
            say RHC::HelpFormatter.new(self).render
          else
            RHC::Helpers.error "The command '#{program :name} #{provided_arguments.join(' ')}' is not recognized.\n"
            say "See '#{program :name} help' for a list of valid commands."
          end
          1
        rescue \
          ArgumentError,
          OptionParser::InvalidOption,
          OptionParser::InvalidArgument,
          OptionParser::MissingArgument => e

          help_bindings = CommandHelpBindings.new(active_command, commands, Commander::Runner.instance.options)
          usage = RHC::HelpFormatter.new(self).render_command(help_bindings)
          RHC::Helpers.error e.message
          say "\n#{usage}"
          1
        rescue RHC::Exception, RHC::Rest::Exception => e
          RHC::Helpers.error e.message
          e.code.nil? ? 128 : e.code
        end
      else
        run_active_command
      end
    end

    def provided_arguments
      @args[0, @args.find_index { |arg| arg.start_with?('-') } || @args.length]
    end

    def global_option(*args, &block)
      opts = args.pop if Hash === args.last
      super(*args, &block).tap do |options|
        options.last.merge!(opts) if opts
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
              RHC::Helpers.error "The command '#{program :name} #{provided_arguments.join(' ')}' is not recognized.\n"
              say "See '#{program :name} help' for a list of valid commands."
              next
            end

            help_bindings = CommandHelpBindings.new command, commands, Commander::Runner.instance.options
            say help_formatter.render_command help_bindings
          end
        end
      end
    end
  end

  class CommandHelpBindings
    def initialize(command, instance_commands, global_options)
      @command = command
      @actions = instance_commands.collect do |command_name, command_class|
        next if command_class.summary.nil?
        m = /^#{command.name} ([^ ]+)/.match(command_name)
        # if we have a match and it is not an alias then we can use it
        m and command_name == command_class.name ? {:name => m[1], :summary => command_class.summary || ""} : nil
      end
      @actions.compact!
      @global_options = global_options
    end
  end
end
