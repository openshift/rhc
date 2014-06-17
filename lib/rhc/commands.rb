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

    alias_method :option_old, :option
    def option(*args, &block)
      opts = args.pop if Hash === args.last
      option_old(*args, &block).tap do |options|
        options.last.merge!(opts) if opts
      end
    end

    #
    # Force proxy_option_struct to default to nil for values,
    # backported for Commander 4.0.3
    #
    def proxy_option_struct
      proxy_options.inject Options.new do |options, (option, value)|
        # options that are present will evaluate to true
        value = true if value.nil?
        # if multiple values were specified for this option, collect it as an
        # array. on 'fill_arguments' we will decide between stick with the array
        # (if :type => :list) or just take the last value from array.
        # not part of the backported method.
        if proxy_options.select{ |item| item[0] == option }.length > 1
          if options[option]
            options[option] << value
          else
            options.__send__ :"#{option}=", [value]
          end
        else
          options.__send__ :"#{option}=", value
        end
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
      remaining = args.split('--').map{ |a| opts.parse!(a) }.inject([]) do |arr, h|
        arr << '--'
        arr.concat(h)
      end
      remaining.shift

      _, config_path = proxy_options.find{ |arg| arg[0] == :config }
      clean, _ = proxy_options.find{ |arg| arg[0] == :clean }

      begin
        @config = RHC::Config.new
        @config.use_config(config_path) if config_path
        @config.sync_additional_config

        $terminal.debug("Using config file #{@config.config_path}")

        unless clean
          local_command_options = (@options.collect{|o| Commander::Runner.switch_to_sym(o[:switches].last.split.first)} rescue [])

          @config.to_options.each_pair do |key, value|  
            next if local_command_options.include?(key)          
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
        @defaults = {}
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
          if !@table.has_key?(meth) && !@defaults.has_key?(meth)
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
      def []=(meth, value)
        @table[meth.to_sym] = value
      end
      def [](meth)
        k = meth.to_sym
        value = @table.has_key?(k) ? @table[k] : @defaults[k]
        value = value.call if value.is_a? Proc
        value
      end
      def __explicit__
        @table
      end
      def ==(other)
        @table == other.instance_variable_get(:@table)
      end
      def default defaults = {}
        @defaults.merge!(__to_hash__(defaults))
      end
      def __replace__(options)
        @table = __to_hash__(options)
      end
      def __hash__
        @defaults.merge(@table)
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
              config.has_configs_from_files?)

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
            option_data = [o[:switches], o[:type], o[:description], o.slice(:optional, :default, :hide, :covered_by)].compact.flatten(1)
            c.option *option_data
            o[:arg] = Commander::Runner.switch_to_sym(Array(o[:switches]).last)
          end

          (args_metadata = Array(opts[:args])).each do |meta|
            switches = meta[:switches]
            unless switches.blank?
              switches = switches.dup
              switches << meta[:description]
              switches << meta.slice(:optional, :default, :hide, :covered_by, :allow_nil)
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

      def self.fill_arguments(cmd, options, args, opts, arguments)
        # process defaults
        defaults = {}
        covers = {}

        (opts + args).each do |option_meta|
          arg = option_meta[:option_symbol] || option_meta[:name] || option_meta[:arg] or next
          if arg && option_meta[:type] != :list && options[arg].is_a?(Array)
            options[arg] = options[arg].last
          end
          Array(option_meta[:covered_by]).each{ |sym| (covers[sym] ||= []) << arg }

          case v = option_meta[:default]
          when Symbol
            cmd.send(v, defaults, arg)
          when Proc
            v.call(defaults, arg)
          when nil
          else
            defaults[arg] = v
          end
        end
        options.default(defaults)

        # process required options
        opts.each do |option_meta|
          raise ArgumentError.new("Missing required option '#{option_meta[:arg]}'.") if option_meta[:required] && options[option_meta[:arg]].nil?
        end

        slots = Array.new(args.count)
        available = arguments.dup

        args.each_with_index do |arg, i|
          value = argument_to_slot(options, available, arg)

          if value.nil?
            if arg[:allow_nil] != true && !arg[:optional]
              raise ArgumentError, "Missing required argument '#{arg[:name]}'."
            end
          end

          slots[i] = value
        end

        raise ArgumentError, "Too many arguments passed in: #{available.reverse.join(" ")}" unless available.empty?

        # reset covered arguments
        options.__explicit__.keys.each do |k|
          if covered = covers[k]
            covered.each do |sym|
              raise ArgumentError, "The options '#{sym}' and '#{k}' cannot both be provided" unless options.__explicit__[sym].nil?
              options[sym] = nil
            end
          end
        end

        slots
      end

      def self.argument_to_slot(options, available, arg)
        if Array(arg[:covered_by]).any?{ |k| !options.__explicit__[k].nil? }
          return nil
        end

        option = arg[:option_symbol]
        value = options.__explicit__[option] if option
        if value.nil?
          value =
            if arg[:type] == :list
              take_leading_list(available)
            else
              v = available.shift
              if v == '--'
                v = nil
              else
                available.shift if available.first == '--'
              end
              v
            end
        end

        value = options[option] if option && (value.nil? || (value.is_a?(Array) && value.blank?))
        if arg[:type] == :list
          value = Array(value)
        end
        options[option] = value if option && !value.nil?

        value
      end

      def self.take_leading_list(available)
        if i = available.index('--')
          left = available.shift(i)
          available.shift
          left
        else
          left = available.dup
          available.clear
          left
        end
      end

      def self.commands
        @commands ||= {}
      end
      def self.global_options
        @options ||= []
      end
  end
end
