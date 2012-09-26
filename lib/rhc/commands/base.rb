require 'commander'
require 'commander/delegates'
require 'rhc/helpers'
require 'rhc/wizard'
require 'rhc/config'
require 'rhc/commands'
require 'rhc/exceptions'
require 'rhc/context_helper'
require 'rhc/output_helper'
class RHC::Commands::Base

  attr_writer :options, :config
  attr_reader :messages

  def initialize(options=Commander::Command::Options.new,
                 config=nil)
    @options, @config = options, config
    @messages = []

    # apply timeout here even though it isn't quite a global
    $rest_timeout = @options.timeout ? @options.timeout.to_i : nil
  end

  def validate_args_and_options(args_metadata, options_metadata, args)
    # process options
    options_metadata.each do |option_meta|
      arg = option_meta[:arg]

      # Check to see if we've provided a value for an option tagged as deprecated
      if (!(val = @options.__hash__[arg]).nil? && dep_info = option_meta[:deprecated])
        # Get the arg for the correct option and what the value should be
        (correct_arg, default) = dep_info.values_at(:key, :value)
        # Set the default value for the correct option to the passed value
        ## Note: If this isn't triggered, then the original default will be honored
        ## If the user specifies any value for the correct option, it will be used
        options.default correct_arg => default
        # Alert the users if they're using a deprecated option
        (correct, incorrect) = [options_metadata.find{|x| x[:arg] == correct_arg },option_meta].flatten.map{|x| x[:switches].join(", ") }
        deprecated_option(incorrect, correct)
      end

      context_helper = option_meta[:context_helper]

      @options.__hash__[arg] = self.send(context_helper) if @options.__hash__[arg].nil? and context_helper
      raise ArgumentError.new("Missing required option '#{arg}'.") if option_meta[:required] and @options.__hash__[arg].nil?
    end

    # process args
    arg_slots = [].fill(nil, 0, args_metadata.length)
    fill_args = args.reverse
    args_metadata.each_with_index do |arg_meta, i|
      # check options
      value = @options.__hash__[arg_meta[:name]]
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

    raise ArgumentError.new("Too many arguments passed in.") unless fill_args.empty?

    arg_slots
  end

  protected
    include RHC::Helpers
    include RHC::ContextHelpers
    include RHC::OutputHelpers

    attr_reader :options, :config

    #
    # The implicit config object provides no defaults.
    #
    def config
      @config ||= begin
        RHC::Config.new
      end
    end

    def application
      #@application ||= ... identify current application or throw,
      #                     indicating one is needed.  Should check
      #                     options (commands which have it as an ARG
      #                     should set it onto options), then check
      #                     current git repo for remote, fail.
    end

    # Return a client object capable of making calls
    # to the OpenShift API that transforms intent
    # and options, to remote calls, and then handle
    # the output (or failures) into exceptions and
    # formatted object output.  Most interactions 
    # should be through this call pattern.
    def rest_client
      @rest_client ||= begin
        username = config.username
        unless username
          username = ask "To connect to #{openshift_server} enter your OpenShift login (email or Red Hat login id): "
          config.config_user(username)
        end
        config.password = config.password || RHC::get_password

        RHC::Rest::Client.new(openshift_rest_node, username, config.password, @options.debug)
      end
    end

    def debug?
      @options.debug
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

      method_name = method.to_s == 'run' ? nil : method.to_s.gsub("_", "-")
      name = [method_name]
      name.unshift(self.object_name).compact!
      raise InvalidCommand, "Either object_name must be set or a non default method defined" if name.empty?
      RHC::Commands.add((@options || {}).merge({
        :name => name.join(' '),
        :class => self,
        :method => method
      }));

      @options = nil
    end

    def self.object_name(value=nil)
      @object_name ||= begin
          value ||= if self.name && !self.name.empty?
            self.name.split('::').last
          end
          value.to_s.split(/(?=[A-Z])/).join('-').downcase if value
        end
    end

    def self.description(*args)
      options[:description] = args.join(' ')
    end
    def self.summary(value)
      options[:summary] = value
    end
    def self.syntax(value)
      options[:syntax] = value
    end
    def self.deprecated(msg)
      options[:deprecated] = msg
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
      options[:root_command] ||= false
      options[:action] = action
      options[:deprecated] ||= false
      aliases << options
    end

    def self.option(switches, description, options={})
      options_metadata << {:switches => switches,
                           :description => description,
                           :context_helper => options[:context],
                           :required => options[:required],
                           :deprecated => options[:deprecated]
                          }
    end

    def self.argument(name, description, switches, options={})
      arg_type = options[:arg_type]
      raise ArgumentError("Only the last argument descriptor for an action can be a list") if arg_type == :list and list_argument_defined?
      list_argument_defined true if arg_type == :list

      args_metadata << {:name => name, :description => description, :switches => switches, :arg_type => arg_type}
    end

    def self.default_action(action)
      define_method(:run) { |*args| send(action, *args) }
    end

    private
      def self.list_argument_defined(bool)
        options[:list_argument_defined] = bool
      end
      def self.list_argument_defined?
        options[:list_argument_defined]
      end
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
