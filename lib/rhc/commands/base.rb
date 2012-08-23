require 'commander'
require 'commander/delegates'
require 'rhc/helpers'
require 'rhc/wizard'
require 'rhc/config'
require 'rhc/commands'
require 'rhc/exceptions'

class RHC::Commands::Base

  def initialize(command=nil,
                 args=[],
                 options=Commander::Command::Options.new,
                 config=RHC::Config)
    @command, @args, @options, @config = command, args, options, config

    # apply timeout here even though it isn't quite a global
    $rest_timeout = @options.timeout ? @options.timeout.to_i : nil
  end

  protected
    include RHC::Helpers

    attr_reader :command, :args, :options, :config

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
        password = RHC::Config.password || RHC::get_password

        RHC::Rest::Client.new(openshift_rest_node, username, password, @options.debug)
      end
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

    def self.alias_action(action)
      aliases << action
    end

    def self.option(switches, description)
      options_metadata << [switches, description].flatten(1)
    end

    def self.argument(name, description, switches)
      args_metadata << {:name => name, :description => description, :switches => switches}
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
