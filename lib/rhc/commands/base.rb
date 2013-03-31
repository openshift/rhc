require 'commander'
require 'commander/delegates'
require 'rhc/helpers'
require 'rhc/wizard'
require 'rhc/config'
require 'rhc/commands'
require 'rhc/exceptions'
require 'rhc/context_helper'

class RHC::Commands::Base

  attr_writer :options, :config

  def initialize(options=Commander::Command::Options.new,
                 config=RHC::Config.new)
    @options, @config = options, config
  end

  protected
    include RHC::Helpers
    include RHC::ContextHelpers

    attr_reader :options, :config

    # Return a client object capable of making calls
    # to the OpenShift API that transforms intent
    # and options, to remote calls, and then handle
    # the output (or failures) into exceptions and
    # formatted object output.  Most interactions 
    # should be through this call pattern.
    def rest_client(opts={})
      @rest_client ||= begin
          auth = RHC::Auth::Basic.new(options)
          auth = RHC::Auth::Token.new(options, auth, token_store) if (options.use_authorization_tokens || options.token) && !(options.rhlogin && options.password)
          client_from_options(:auth => auth)
        end
    end

    def token_store
      @token_store ||= RHC::Auth::TokenStore.new(config.home_conf_path)
    end

    def help(*args)
      raise ArgumentError, "Please specify an action to take"
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

      prefix = self.object_name
      method_name = method.to_s == 'run' ? nil : method.to_s.gsub("_", "-")
      name = [prefix, method_name].compact
      raise InvalidCommand, "Either object_name must be set or a non default method defined" if name.empty?

      aliases.each{ |a| a[:action] = [prefix, a[:action]] unless a[:root_command] || prefix.nil? }

      RHC::Commands.add((@options || {}).merge({
        :name => name,
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
      o = args.join(' ')
      options[:description] = o.strip_heredoc
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

    #
    # Provide an alias to the command.  The alias will not be shown in help, but will
    # be available in autocompletion and at execution time.
    #
    # Supported options:
    # 
    #   :deprecated - if true, a warning will be displayed when the command is executed
    #   :root_command - if true, do not prepend the object name to the command
    # 
    def self.alias_action(action, options={})
      options[:action] = action
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

      option_symbol = Commander::Runner.switch_to_sym(switches.last)
      args_metadata << {:name => name,
                        :description => description,
                        :switches => switches,
                        :context_helper => options[:context],
                        :option_symbol => option_symbol,
                        :arg_type => arg_type}
    end

    def self.default_action(action)
      options[:default] = action unless action == :help
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
      def self.aliases
        options[:aliases] ||= []
      end
      def self.options
        @options ||= {}
      end
end
