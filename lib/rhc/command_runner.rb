module RHC
  class CommandRunner < Commander::Runner
    # regex fix from git - match on word boundries
    def valid_command_names_from *args
      arg_string = args.delete_if { |value| value =~ /^-/ }.join ' '
      commands.keys.find_all { |name| name if /^#{name}\b/.match arg_string }
    end

    if Commander::VERSION == '4.0.3'
      #:nocov:
      def program(*args)
        Array(super).first
      end
      #:nocov:
    end

    def options_parse_trace
      if @args.include?("--trace")
        @args.delete "--trace"
        return true
      end
      false
    end

    def options_parse_debug
      if @args.include?("-d") or @args.include?("--debug")
        @args.delete "-d"
        @args.delete "--debug"
        return true
      end
      false
    end

    def options_parse_version
      if @args.include? "--version"
        say version
        exit 0
      end
    end

    HELP_OPTIONS = ['--help', '-h']

    def options_parse_help
      if (@args & HELP_OPTIONS).present?
        args = (@args -= HELP_OPTIONS)
        args.shift if args.first == 'help' && !command_exists?(args.join(' '))
        exit run_help(args)
      end
    end

    # override so we can do our own error handling
    def run!
      trace = false
      require_program :version, :description

      global_option('-h', '--help', 'Help on any command', :hide => true)
      global_option('--version', 'Display version information', :hide => true)

      # special case --debug so all commands can output relevant info on it
      $terminal.debug = options_parse_debug

      # special case --trace because we need to use it in the runner
      trace = options_parse_trace

      # special case --version so it is processed before an invalid command
      options_parse_version

      # help is a special branch prior to command execution
      options_parse_help

      unless trace
        begin
          run_active_command
        rescue InvalidCommandError => e
          run_help(provided_arguments)
        rescue \
          OptionParser::InvalidOption => e
          RHC::Helpers.error e.message
          1
        rescue \
          ArgumentError,
          OptionParser::ParseError => e

          help_bindings = CommandHelpBindings.new(active_command, commands, self)
          usage = RHC::HelpFormatter.new(self).render_command_syntax(help_bindings)
          message = case e
          when OptionParser::AmbiguousOption
            "The option #{e.args.join(' ')} is ambiguous. You will need to specify the entire option."
          else
            e.message
          end

          RHC::Helpers.error message
          say "#{usage}"
          1
        rescue RHC::Exception, RHC::Rest::Exception => e
          RHC::Helpers.error e.message
          e.code.nil? ? 128 : [1, (e.code || 1).to_i].max
        end
      else
        run_active_command
      end
    end

    def provided_arguments
      @args[0, @args.find_index { |arg| arg != '--' and arg.start_with?('-') } || @args.length]
    end

    def global_option(*args, &block)
      opts = args.pop if Hash === args.last
      super(*args, &block).tap do |options|
        options.last.merge!(opts) if opts
      end
    end

    def create_default_commands
      command 'help options' do |c|
        c.description = "Display all global options and information about configuration"
        c.when_called do |args, options|
          say help_formatter.render_options self
          0
        end
      end
      command :help do |c|
        c.syntax = '<command>'
        c.description = 'Display global or <command> help documentation.'
        c.when_called(&method(:run_help))
      end
    end

    def run_help(args=[], options=nil)
      args.delete_if{ |a| a.start_with? '-' }
      unless args[0] == 'commands'
        variations = (1..args.length).reverse_each.map{ |n| args[0,n].join('-') }
        cmd = variations.find{ |cmd| command_exists?(cmd) }
      end

      if args.empty?
        say help_formatter.render
        0
      else
        if cmd.nil?
          matches = (variations || ['']).inject(nil) do |candidates, term|
            term = term.downcase
            keys = commands.keys.map(&:downcase)
            prefix, keys = keys.partition{ |n| n.start_with? term }
            inline, keys = keys.partition{ |n| n.include? term }
            break [term, prefix, inline] unless prefix.empty? && inline.empty?
          end

          unless matches
            RHC::Helpers.error "The command '#{program :name} #{provided_arguments.join(' ')}' is not recognized.\n"
            say "See '#{program :name} help' for a list of valid commands."
            return 1
          end

          candidates = (matches[1] + matches[2]).map{ |n| commands[n] }.uniq.sort_by{ |c| c.name }
          if candidates.length == 1
            cmd = candidates.first.name
          else
            RHC::Helpers.pager
            RHC::Helpers.say matches[0] != '' ? "Showing commands matching '#{matches[0]}'" : "Showing all commands"
            candidates.reverse.each do |command|
              RHC::Helpers.paragraph do
                aliases = (commands.map{ |(k,v)| k if command == v }.compact - [command.name]).map{ |s| "'#{s}'"}
                aliases[0] = "(also #{aliases[0]}" if aliases[0]
                aliases[-1] << ')' if aliases[0]

                RHC::Helpers.header [RHC::Helpers.color(command.name, :cyan), *aliases.join(', ')]
                say command.description || command.summary
              end
            end
            return 1
          end
        end

        RHC::Helpers.pager
        command = command(cmd)
        help_bindings = CommandHelpBindings.new command, commands, self
        say help_formatter.render_command help_bindings
        0
      end
    end
  end
end
