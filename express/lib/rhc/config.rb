require 'rhc/vendor/parseconfig'
require 'rhc/core_ext'

module RHC
  module Config
    # FIXME: Config shouldn't really exit
    #        stub this out for now so we can test it
    def self.exit(code)
      # :nocov:
      Kernel.exit(code)
      # :nocov:
    end

    def self.read_config_files
      @@global_config = RHC::Vendor::ParseConfig.new(@@global_config_path) if File.exists?(@@global_config_path)
      @@local_config = RHC::Vendor::ParseConfig.new(File.expand_path(@@local_config_path)) if File.exists?(@@local_config_path)
    rescue Errno::EACCES => e
      say "Could not open config file: #{e.message}"
      exit 253
    end

    def self.initialize
      @@defaults = RHC::Vendor::ParseConfig.new()
      @@global_config = nil
      @@local_config = nil
      @@opts_config = nil
      @@default_proxy = nil
      @@env_config = RHC::Vendor::ParseConfig.new()

      @@defaults.add('libra_server', 'openshift.redhat.com')
      @@env_config.add('libra_server', ENV['LIBRA_SERVER']) if ENV['LIBRA_SERVER']

      #
      # Config paths... /etc/openshift/express.conf or $GEM/conf/express.conf -> ~/.openshift/express.conf
      #

      @@conf_name = 'express.conf'
      _linux_cfg = '/etc/openshift/' + @@conf_name
      _gem_cfg = File.join(File.expand_path(File.dirname(__FILE__) + "/../../conf"), @@conf_name)

      @@global_config_path = File.exists?(_linux_cfg) ? _linux_cfg : _gem_cfg
      @@home_dir = File.expand_path("~")
      @@home_conf_path = File.join(@@home_dir, '.openshift')
      @@local_config_path = File.join(@@home_conf_path, @@conf_name)

      self.read_config_files
    end

    self.initialize

    # used for tests
    def self.home_dir=(home_dir)
      @@home_dir=home_dir
      @@home_conf_path = File.join(@@home_dir, '.openshift')
      @@local_config_path = File.join(@@home_conf_path, @@conf_name)
      @@local_config = nil
      @@local_config = RHC::Vendor::ParseConfig.new(File.expand_path(@@local_config_path)) if File.exists?(@@local_config_path)
    end

    def self.[](key)
      # evaluate in cascading order
      configs = [@@opts_config, @@env_config, @@local_config, @@global_config, @@defaults]
      result = nil
      configs.each do |conf|
        result = conf[key] if !conf.nil?
        break if !result.nil?
      end

      result
    end

    def self.get_value(key)
      self[key]
    end

    # Public: configures the default user for this session
    def self.config_user(username)
      @@defaults.add('default_rhlogin', username)
    end

    def self.set_local_config(confpath)
      begin
        @@local_config = RHC::Vendor::ParseConfig.new(File.expand_path(confpath))
      rescue Errno::EACCES => e
        say "Could not open config file: #{e.message}"
        exit 253
      end
    end

    def self.set_opts_config(confpath)
      begin
        @@opts_config = RHC::Vendor::ParseConfig.new(File.expand_path(confpath))
      rescue Errno::EACCES => e
        say "Could not open config file: #{e.message}"
        exit 253
      end
    end

    def self.check_cpath(opts)
      unless opts["config"].nil?
        opts_config_path = File.expand_path(opts["config"])
        if !File.readable?(opts_config_path)
          say "Could not open config file: #{@opts_config_path}"
          exit 253
        else
          set_opts_config(opts_config_path)
        end
      end
    end

    def self.has_global_config?
      !@@global_config.nil?
    end

    def self.has_local_config?
      !@@local_config.nil?
    end

    def self.has_opts_config?
      !@@opts_config.nil?
    end

    # Public: convinience function to see if we should run the wizard
    def self.should_run_wizard?
      not (has_local_config? or has_opts_config?)
    end

    def self.local_config_path
      @@local_config_path
    end

    def self.home_conf_path
      @@home_conf_path
    end

    def self.home_dir
      @@home_dir
    end

    def self.default_rhlogin
      get_value('default_rhlogin')
    end

    def self.default_proxy
      #
      # Check for proxy environment
      #
      if @@default_proxy.nil?
        if ENV['http_proxy']
          if ENV['http_proxy']!~/^(\w+):\/\// then
            ENV['http_proxy']="http://" + ENV['http_proxy']
          end
          proxy_uri=URI.parse(ENV['http_proxy'])
          @@default_proxy = Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
        else
          @@default_proxy = Net::HTTP
        end
      end
      @@default_proxy
    end
  end
end
