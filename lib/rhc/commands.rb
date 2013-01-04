require 'commander'
require 'commander/command'

## monkey patch option parsing to also parse global options all at once
#  to avoid conflicts and side effects of similar short switches
module Commander
  class Command
    attr_accessor :default_action
    def default_action?
      default_action.present?
    end

    def parse_options_and_call_procs *args
      return args if args.empty?
      opts = OptionParser.new
      runner = Commander::Runner.instance
      # add global options
      runner.options.each do |option|
        opts.on *option[:args],
                &runner.global_option_proc(option[:switches], &option[:proc])

      end

      # add command options
      @options.each do |option|
        opts.on(*option[:args], &option[:proc])
        opts
      end

      opts.parse! args
    end
  end
end

#
# Allow Command::Options to lazily evaluate procs and lambdas
#
module Commander
  class Command
    class Options
      def initialize(init=nil)
        @table = {}
        default(init) if init
      end
      def method_missing meth, *args, &block
        meth.to_s =~ /=$/ ? self[meth.to_s.chop] = args.first : self[meth]
      end
      def []=(meth, value)
        @table[meth.to_sym] = value
      end
      def [](meth)
        value = @table[meth.to_sym]
        value = value.call if value.is_a? Proc
        value
      end
      def default defaults = {}
        @table = @table.reverse_merge!(__to_hash__(defaults))
      end
      def __replace__(options)
        @table = __to_hash__(options).dup
      end
      def __to_hash__(obj)
        Options === obj ? obj.__hash__ : obj
      end
    end
  end
end

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

    def self.deprecated?
      command_name = Commander::Runner.instance.command_name_from_args
      command = Commander::Runner.instance.active_command

      new_cmd = deprecated[command_name.to_sym]
      if new_cmd
        new_cmd = "rhc #{command.name}" if new_cmd == true
        RHC::Helpers.deprecated_command new_cmd
      end
    end

    def self.needs_configuration!(cmd, options, config)
      if not (cmd.class.suppress_wizard? or
              options.noprompt or
              options.help or
              config.has_local_config? or
              config.has_opts_config?)

        RHC::Helpers.warn(
          "You have not yet configured the OpenShift client tools. Please run 'rhc setup'.",
            :stderr => true)
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
          c.default_action = opts[:default]

          (options_metadata = opts[:options] || []).each do |o|
            option_data = [o[:switches], o[:description]].flatten(1)
            c.option *option_data
            o[:arg] = Commander::Runner.switch_to_sym(o[:switches].last)
          end

          deprecated[name.to_sym] = opts[:deprecated] unless opts[:deprecated].nil?

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
                alias_cmd = alias_components.join(' ').to_sym
              end

              deprecated[alias_cmd] = true if a[:deprecated]
              instance.alias_command "#{alias_cmd}", :"#{name}"
            end
          end

          c.when_called do |args, options|
            config = RHC::Config.new
            config.set_opts_config(options.config) if options.config

            options.default(config.to_options) unless options.clean
            deprecated?

            cmd = opts[:class].new
            cmd.options = options
            cmd.config = config

            args = fill_arguments(cmd, options, args_metadata, options_metadata, args)
            needs_configuration!(cmd, options, config)
            execute(cmd, opts[:method], args)
          end
        end
      end
      self
    end

    protected
      def self.execute(cmd, method, args)
        cmd.send(method, *args)
      end

      def self.fill_arguments(cmd, options, args_metadata, options_metadata, args)
        # process options
        options_metadata.each do |option_meta|
          arg = option_meta[:arg]

          # Check to see if we've provided a value for an option tagged as deprecated
          if (!(val = options.__hash__[arg]).nil? && dep_info = option_meta[:deprecated])
            # Get the arg for the correct option and what the value should be
            (correct_arg, default) = dep_info.values_at(:key, :value)
            # Set the default value for the correct option to the passed value
            ## Note: If this isn't triggered, then the original default will be honored
            ## If the user specifies any value for the correct option, it will be used
            options.default correct_arg => default
            # Alert the users if they're using a deprecated option
            (correct, incorrect) = [options_metadata.find{|x| x[:arg] == correct_arg },option_meta].flatten.map{|x| x[:switches].join(", ") }
            RHC::Helpers.deprecated_option(incorrect, correct)
          end

          if context_helper = option_meta[:context_helper]
            options[arg] = lambda{ cmd.send(context_helper) } if options.__hash__[arg].nil?
          end
          raise ArgumentError.new("Missing required option '#{arg}'.") if option_meta[:required] && options[arg].nil?
        end

        # process args
        arg_slots = [].fill(nil, 0, args_metadata.length)
        fill_args = args.reverse
        args_metadata.each_with_index do |arg_meta, i|
          # check options
          value = options.__hash__[arg_meta[:option_symbol]] unless arg_meta[:option_symbol].nil?
          if value
            arg_slots[i] = value
          elsif arg_meta[:arg_type] == :list
            arg_slots[i] = fill_args.reverse
            fill_args = []
          else
            raise ArgumentError.new("Missing required argument '#{arg_meta[:name]}'.") if fill_args.empty?
            arg_slots[i] = fill_args.pop
          end
        end

        raise ArgumentError.new("Too many arguments passed in: #{fill_args.reverse.join(" ")}") unless fill_args.empty?

        arg_slots
      end

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
