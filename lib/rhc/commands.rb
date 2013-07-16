require 'commander'
require 'commander/command'

## monkey patch option parsing to also parse global options all at once
#  to avoid conflicts and side effects of similar short switches
module Commander
  class Command
    attr_accessor :default_action, :root, :info
    def default_action?
      default_action.present?
    end
    def root?
      root.present?
    end

    #
    # Force proxy_option_struct to default to nil for values,
    # backported for Commander 4.0.3 
    #
    def proxy_option_struct
      proxy_options.inject Options.new do |options, (option, value)|
        # options that are present will evaluate to true
        value = true if value.nil?
        options.__send__ :"#{option}=", value
        options
      end
    end    

    def deprecated(as_alias=nil)
      return false unless info
      return info[:deprecated] if info[:deprecated]
      return false unless info[:aliases]
      info[:aliases].select{ |a| ['-',' '].map{ |s| Array(a[:action]).join(s) }.include?(as_alias) }.map{ |a| a[:deprecated] }.first if as_alias
    end

    def parse_options_and_call_procs *args
      runner = Commander::Runner.instance
      opts = OptionParser.new

      # add global options
      runner.options.each do |option|
        opts.on(*option[:args], &runner.global_option_proc(option[:switches], &option[:proc]))
      end

      # add command options
      @options.each do |option|
        opts.on(*option[:args], &option[:proc])
        opts
      end

      # Separate option lists with '--'
      remaining = args.split('--').map{ |a| opts.parse!(a) }.inject([]) do |arr, sub|
        arr << '--' unless arr.empty?
        arr.concat(sub)
      end

      _, config_path = proxy_options.find{ |arg| arg[0] == :config }
      clean, _ = proxy_options.find{ |arg| arg[0] == :clean }

      begin
        @config = RHC::Config.new
        @config.use_config(config_path) if config_path
        $terminal.debug("Using config file #{@config.config_path}")

        unless clean
          @config.to_options.each_pair do |key, value|
            next if proxy_options.detect{ |arr| arr[0] == key }
            if sw = opts.send(:search, :long, key.to_s.gsub(/_/, '-'))
              _, cb, val = sw.send(:conv_arg, nil, value) {|*exc| raise(*exc) }
              cb.call(val) if cb
            else
              proxy_options << [key, value]
            end
          end
        end
      rescue ArgumentError => e
        n = OptionParser::InvalidOption.new(e.message)
        n.reason = "The configuration file #{@config.path} contains an invalid setting"
        n.set_backtrace(e.backtrace)
        raise n
      rescue OptionParser::ParseError => e
        e.reason = "The configuration file #{@config.path} contains an invalid setting"
        raise
      end
      remaining
    end
  end
end

#
# Allow Command::Options to lazily evaluate procs and lambdas
#
module Commander
  class Command
    remove_const(:Options)
    class Options
      def initialize(init=nil)
        @table = {}
        default(init) if init
      end
      def respond_to?(meth)
        super || meth.to_s =~ /^\w+(=)?$/
      end
      def method_missing meth, *args, &block
        if meth.to_s =~ /^\w+=$/
          raise ArgumentError, "Options does not support #{meth} without a single argument" if args.length != 1
          self[meth.to_s.chop] = args.first
        elsif meth.to_s =~ /^\w+$/
          if !@table.has_key?(meth)
            begin; return super; rescue NoMethodError; nil; end
          end
          raise ArgumentError, "Options does not support #{meth} with arguments" if args.length != 0
          self[meth]
        else
          super
        end
      end
      def respond_to_missing?(meth, private_method = false)
        meth.to_s =~ /^\w+(=)?$/
      end
      def ==(other)
        __hash__ == other.__hash__
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
      def __hash__
        @table
      end
      def __to_hash__(obj)
        Options === obj ? obj.__hash__ : obj
      end
    end
  end
end

module RHC
  module Commands
    autoload :Base, 'rhc/commands/base'

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
      global_options << [args.freeze, block]
    end

    def self.deprecated!
      instance = Commander::Runner.instance
      command_name = instance.command_name_from_args
      command = instance.active_command

      if new_cmd = command.deprecated(command_name)
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

        $stderr.puts RHC::Helpers.color("You have not yet configured the OpenShift client tools. Please run 'rhc setup'.", :yellow)
      end
    end

    def self.to_commander(instance=Commander::Runner.instance)
      global_options.each do |args, block|
        args = args.dup
        opts = (args.pop if Hash === args.last) || {}
        option = instance.global_option(*args, &block).last
        option.merge!(opts)
      end
      commands.each_pair do |name, opts|
        name = Array(name)
        names = [name.reverse.join('-'), name.join(' ')] if name.length > 1
        name = name.join('-')

        instance.command name do |c|
          c.description = opts[:description]
          c.summary = opts[:summary]
          c.syntax = opts[:syntax]
          c.default_action = opts[:default]

          c.info = opts

          (options_metadata = Array(opts[:options])).each do |o|
            option_data = [o[:switches], o[:description]].flatten(1)
            c.option *option_data
            o[:arg] = Commander::Runner.switch_to_sym(Array(o[:switches]).last)
          end

          (args_metadata = Array(opts[:args])).each do |meta|
            switches = meta[:switches]
            unless switches.nil? or switches.empty?
              switches << meta[:description]
              c.option *switches
            end
          end

          Array(opts[:aliases]).each do |a|
            action = Array(a[:action])
            [' ', '-'].each do |s|
              cmd = action.join(s)
              instance.alias_command cmd, name
            end
          end

          if names
            names.each{ |alt| instance.alias_command alt, name }
          else
            c.root = true
          end

          c.when_called do |args, options|
            deprecated!
            
            config = c.instance_variable_get(:@config)
            
            cmd = opts[:class].new
            cmd.options = options
            cmd.config = config
            
            args = fill_arguments(cmd, options, args_metadata, options_metadata, args)
            needs_configuration!(cmd, options, config)
            
            return execute(cmd, :help, args) unless opts[:method]
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
        Commander::Runner.instance.options.each do |opt|
          if opt[:context]
            arg = Commander::Runner.switch_to_sym(opt[:switches].last)
            options.__hash__[arg] ||= lambda{ cmd.send(opt[:context]) }
          end
        end

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

        available = args.dup
        slots = Array.new(args_metadata.length)
        args_metadata.each_with_index do |arg, i|
          option = arg[:option_symbol]
          context_helper = arg[:context_helper]

          value = options.__hash__[option] if option

          if value.nil?
            value =
              if arg[:arg_type] == :list
                all = []
                while available.first && available.first != '--'
                  all << available.shift
                end
                available.shift if available.first == '--'
                all
              else
                available.shift
              end
          end

          value = cmd.send(context_helper) if value.nil? and context_helper

          if value.nil?
            raise ArgumentError, "Missing required argument '#{arg[:name]}'." unless arg[:optional]
            break if available.empty?
          else
            value = Array(value) if arg[:arg_type] == :list
            slots[i] = value
            options.__hash__[option] = value if option
          end
        end

        raise ArgumentError, "Too many arguments passed in: #{available.reverse.join(" ")}" unless available.empty?

        slots
      end

      def self.commands
        @commands ||= {}
      end
      def self.global_options
        @options ||= []
      end
  end
end
