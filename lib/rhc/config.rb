require 'rhc/vendor/parseconfig'
require 'rhc/core_ext'

module RHC

  module ConfigEnv
    def conf_name
      'express.conf'
    end
    def home_conf_dir
      File.join(home_dir, '.openshift')
    end
    def local_config_path
      File.join(home_conf_dir, conf_name)
    end
    def ssh_dir
      File.join(home_dir, '.ssh')
    end
    def ssh_priv_key_file_path
      File.join(ssh_dir, 'id_rsa')
    end
    def ssh_pub_key_file_path
      File.join(ssh_dir, 'id_rsa.pub')
    end
  end

  class Config
    include ConfigEnv

    def self.default
      @default ||= RHC::Config.new
    end

    def self.method_missing(method, *args, &block)
      if default.respond_to?(method)
        default.send(method, *args, &block)
      else
        raise NoMethodError, method
      end
    end

    def self.initialize
      @default = nil
      default
    end

    def initialize
      set_defaults
    end

    def read_config_files
      load_config_files
    end

    def set_defaults
      @defaults = RHC::Vendor::ParseConfig.new()
      @opts  = RHC::Vendor::ParseConfig.new() # option switches that override config file

      @env_config = RHC::Vendor::ParseConfig.new()
      @global_config = nil
      @local_config = nil
      @opts_config = nil # config file passed in the options

      @default_proxy = nil

      @defaults.add('libra_server', 'openshift.redhat.com')
      @env_config.add('libra_server', ENV['LIBRA_SERVER']) if ENV['LIBRA_SERVER']

      @opts_config_path = nil
    end

    def [](key)
      #raise KeyError("Please use RHC::Config.password to access the password config") if key == "password"
      lazy_init

      # evaluate in cascading order
      configs = [@opts, @opts_config, @env_config, @local_config, @global_config, @defaults]
      result = nil
      configs.each do |conf|
        result = conf[key] if !conf.nil?
        break if !result.nil?
      end

      result
    end

    def get_value(key)
      self[key]
    end

    def username
      self['default_rhlogin']
    end

    # Public: configures the default user for this session
    def config_user(username)
      @defaults.add('default_rhlogin', username)
    end

    def opts_login=(username)
      @opts.add('default_rhlogin', username)
    end

    def opts_login
      @opts['default_rhlogin']
    end

    # password is not allowed in config files and can only be passed on comman line
    def password=(password)
      @opts.add('password', password)
    end

    def password
      self['password']
    end

    def set_local_config(conf_path, must_exist=true)
      conf_path = File.expand_path(conf_path)
      @config_path = conf_path if @opts_config_path.nil?
      @local_config = RHC::Vendor::ParseConfig.new(conf_path)
    rescue Errno::EACCES => e
      raise Errno::EACCES.new "Could not open config file: #{e.message}" if must_exist
    end

    def set_opts_config(conf_path)
      @opts_config_path = File.expand_path(conf_path)
      @config_path = @opts_config_path
      @opts_config = RHC::Vendor::ParseConfig.new(@opts_config_path) if File.exists?(@opts_config_path)
    rescue Errno::EACCES => e
      raise Errno::EACCES.new "Could not open config file: #{e.message}"
    end

    def check_cpath(opts)
      unless opts["config"].nil?
        opts_config_path = File.expand_path(opts["config"])
        if !File.readable?(opts_config_path)
          raise Errno::EACCES.new "Could not open config file: #{@opts_config_path}"
        else
          set_opts_config(opts_config_path)
        end
      end
    end

    def global_config_path
      linux_cfg = '/etc/openshift/' + conf_name
      File.exists?(linux_cfg) ? linux_cfg : File.join(File.expand_path(File.dirname(__FILE__) + "/../../conf"), conf_name)
    end

    def has_global_config?
      lazy_init
      !@global_config.nil?
    end

    def has_local_config?
      lazy_init
      !@local_config.nil?
    end

    def has_opts_config?
      !@opts_config.nil?
    end
    
    def has_opts?
      !@opts.nil?
    end

    def should_run_ssh_wizard?
      not File.exists? ssh_priv_key_file_path
    end

    ##
    # config_path
    #
    # authoritive configuration path
    # this is used to determine where config options should be written to
    # when a script modifies the config such as in rhc setup
    def config_path
      @config_path ||= local_config_path
    end

    def home_dir
      RHC::Config.home_dir
    end

    def home_conf_path
      home_conf_dir
    end

    def default_rhlogin
      get_value('default_rhlogin')
    end

    def default_proxy
      @default_proxy ||= (
        proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']
        if proxy
          if proxy !~ /^(\w+):\/\// then
            proxy = "http://#{proxy}"
          end
          ENV['http_proxy'] = proxy
          proxy_uri = URI.parse(ENV['http_proxy'])
          Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
        else
          Net::HTTP
        end
      )
    end

    def using_proxy?
      default_proxy.instance_variable_get(:@is_proxy_class) || false
    end

    def proxy_vars
      Hash[[:address,:user,:pass,:port].map do |x|
        [x,default_proxy.instance_variable_get("@proxy_#{x}")]
      end]
    end

    private
      # Allow mocking of the home dir
      def self.home_dir
        #raise "Why am I not stubbed?"
        File.expand_path('~')
      end

      def load_config_files
        @global_config = RHC::Vendor::ParseConfig.new(global_config_path) if File.exists?(global_config_path)
        @local_config = RHC::Vendor::ParseConfig.new(File.expand_path(local_config_path)) if File.exists?(local_config_path)
      rescue Errno::EACCES => e
        raise Errno::EACCES.new("Could not open config file: #{e.message}")
      end

      def lazy_init
        unless @loaded
          load_config_files
          @loaded = true
        end
      end
  end
end
