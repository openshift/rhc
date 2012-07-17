require 'commander'
require 'commander/delegates'
require 'rhc/helpers'
require 'rhc/wizard'
require 'rhc/config'

class RHC::Commands::Base

  def initialize(command=nil, args=[], options=OptionParser.new)
    @command, @args, @options = command, args, options
  end

  protected
    include RHC::Helpers

    attr_reader :command, :args, :options

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

    def config
      @config ||= begin
        RHC::Config.set_opts_config(options.config) if options.config
        RHC::Config.password = options.password if options.password
        RHC::Config.opts_login = options.rhlogin if options.rhlogin
        RHC::Config
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

    def self.suppress_wizard
      @suppress_wizard = true
    end

    def self.suppress_wizard?
      @suppress_wizard
    end

    def run
      if not self.class.suppress_wizard? and RHC::Config.should_run_wizard?
        w = RHC::Wizard.new(RHC::Config.local_config_path)
        w.run
      end
    end

    private

      def self.options
        @options ||= {}
      end
end
