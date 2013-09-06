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
          auth = auth_config
          debug "Authenticating with #{auth.class}"
          client_from_options(:auth => auth)
        end

        if opts[:min_api] && opts[:min_api].to_f > @rest_client.api_version_negotiated.to_f
          raise RHC::ServerAPINotSupportedException.new(opts[:min_api], @rest_client.api_version_negotiated)
        end

      @rest_client
    end

    def auth_config
      @auth ||= begin
          if (options.use_authorization_tokens || options.token) && !((options.rhlogin && options.password) || options.gssapi)
            base_auth = RHC::Auth::Basic.new(options)
            base_auth = RHC::Auth::Negotiate.new(options) if options.use_gssapi
            RHC::Auth::Token.new(options, base_auth, token_store)
          elsif options.use_gssapi || options.gssapi
            RHC::Auth::Negotiate.new(options)
          else
            RHC::Auth::Basic.new(options) 
          end
      end
      @auth
    end

    def token_store
      @token_store ||= RHC::Auth::TokenStore.new(config.home_conf_path)
    end

    def help(*args)
      raise ArgumentError, "Please specify an action to take"
    end

    class InvalidCommand < StandardError ; end

    def self.method_added(method)
      return if self == RHC::Commands::Base
      return if private_method_defined? method
      return if protected_method_defined? method

      prefix = self.object_name
      method_name = method.to_s == 'run' ? nil : method.to_s.gsub("_", "-")
      name = [prefix, method_name].compact
      raise InvalidCommand, "Either object_name must be set or a non default method defined" if name.empty?

      aliases.each{ |a| a[:action].unshift(prefix) unless a[:root_command] } if prefix

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
      options[:action] = action.is_a?(Array) ? action : action.to_s.split(' ')
      aliases << options
    end

    def self.option(switches, description, options={})
      options_metadata << {:switches => switches,
                           :description => description,
                           :context_helper => options[:context],
                           :required => options[:required],
                           :deprecated => options[:deprecated],
                           :option_type => options[:option_type]
                          }
    end

    def self.argument(name, description, switches=[], options={})
      arg_type = options[:arg_type]

      option_symbol = Commander::Runner.switch_to_sym(switches.last)
      args_metadata << {:name => name,
                        :description => description,
                        :switches => switches,
                        :context_helper => options[:context],
                        :option_symbol => option_symbol,
                        :optional => options[:optional],
                        :arg_type => arg_type}
    end

    def self.default_action(action)
      options[:default] = action unless action == :help
      name = self.object_name
      raise InvalidCommand, "object_name must be set" if name.empty?

      RHC::Commands.add((@options || {}).merge({
        :name => name,
        :class => self,
        :method => options[:default]
      }));
    end

  private
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
