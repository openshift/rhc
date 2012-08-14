require 'commander'
require 'commander/delegates'
require 'rhc/helpers'
require 'rhc/wizard'
require 'rhc/config'
require 'rhc/commands'
require 'rhc/exceptions'

class RHC::Commands::Base

  def initialize(command=nil,
                 options=Commander::Command::Options.new,
                 config=RHC::Config)
    @command, @options, @config = command, options, config
    # apply timeout here even though it isn't quite a global
    $rest_timeout = @options.timeout ? @options.timeout.to_i : nil
  end

  def fill_and_validate_args(args_metadata, args, options)
    raise ArgumentError.new("Invalid arguments") if args.length > args_metadata.length

    ##
    # Argument fill and validate algorithm
    #
    # 1.) process args_metadata filling in arg slots with any switches found
    # 2.) backfill empty arg slots from right to left with passed in args
    # 3.) try to fill in any empty slots by calling their context callback
    # 4.) Validate all arguments are filled in (e.g. not nil) and return
    arg_slots = [].fill(nil, 0, args_metadata.length)
    backfill_args = args.dup

    # squash algorithm into single pass loop
    # manually handle negitive index because there is no reverse_each_index array method
    args_metadata.reverse.each_with_index do |arg_meta, i|

      # check switches
      value = options.__hash__[arg_meta[:name]]
      if value.nil?
        unless backfill_args.empty?
          # backfill an arg
          value = backfill_args.pop
        else
          # try to call the context callback
          context_helper = arg_meta[:context_helper]
          raise ArgumentError.new("Missing a manditory argument") if context_helper.nil?

          value = self.send(context_helper)
          raise ArgumentError.new("Could not obtain the #{arg_meta[:name]} context.  You may need to fill this information in manually.") if value.nil?
        end
      end

      arg_slots[i] = value
    end

    # validate all args have been filled in (e.g. no backfill args left)
    raise ArgumentError.new("Too many arguments passed in.") unless backfill_args.empty?

    arg_slots.reverse
  end

  protected
    include RHC::Helpers
    include RHC::ContextHelpers

    attr_reader :command, :options, :config

    def application
      #@application ||= ... identify current application or throw,
      #                     indicating one is needed.  Should check
      #                     options (commands which have it as an ARG
      #                     should set it onto options), then check
      #                     current git repo for remote, fail.
    end

    def client
      #@client ||= ... Return a client object capable of making calls
      #                to the OpenShift API that transforms intent
      #                and options, to remote calls, and then handle
      #                the output (or failures) into exceptions and
      #                formatted object output.  Most interactions 
      #                should be through this call pattern.
      #
      #                Initialize with auth (a separate responsibility
      #                object).
    end

    class InvalidCommand < StandardError ; end

    def self.inherited(klass)
      unless klass == RHC::Commands::Base
      end
    end

    def self.method_added(method)
      return if self == RHC::Commands::Base
      return if private_method_defined? method
      return if protected_method_defined? method

      method_name = method.to_s == 'run' ? nil : method.to_s
      name = [method_name]
      name.unshift(self.object_name).compact!
      raise InvalidCommand, "Either object_name must be set or a non default method defined" if name.empty?
      RHC::Commands.add((@options || {}).merge({
        :name => name.join(' '),
        :class => self,
        :method => method,
      }));
      @options = nil
    end

    def self.object_name(value=nil)
      @object_name ||= begin
          value ||= if self.name && !self.name.empty?
            self.name.split('::').last
          end
          value.to_s.downcase if value
        end
    end

    def self.description(value)
      options[:description] = value
    end
    def self.summary(value)
      options[:summary] = value
    end
    def self.syntax(value)
      options[:syntax] = value
    end

    def self.suppress_wizard
      @suppress_wizard = true
    end

    def self.suppress_wizard?
      @suppress_wizard
    end

    def self.alias_action(action, options={})
      # if it is a root_command we simply alias it to the passed in action
      # if not we prepend the current resource to the action
      # default == false
      root_command = options[:root_command] || false
      aliases << [action, root_command]
    end

    def self.option(switches, description)
      options_metadata << [switches, description].flatten(1)
    end

    def self.argument(name, description, switches, options={})
      context_helper = options[:context]
      args_metadata << {:name => name, :description => description, :switches => switches, :context_helper => context_helper}
    end

    def self.default_action(action)
      define_method(:run) { |*args| send(action, *args) }
    end

    private
      def self.options_metadata
        options[:options] ||= []
      end
      def self.args_metadata
        options[:args] ||= []
      end
      def self.options
        @options ||= {}
      end
      def self.aliases
        options[:aliases] ||= []
      end
end
