require 'rhc/vendor/parseconfig'
require 'rhc/core_ext'

module RHC
  class Config

    def self.default
      @default ||= begin
        RHC::Config.new
      end.tap do |c|
        c.read_config_files
      end
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

      _gem_cfg = File.join(File.expand_path(File.dirname(__FILE__) + "/../../conf"), @conf_name)
      @global_config_path = File.exists?(@_linux_cfg) ? @_linux_cfg : _gem_cfg
    end

    def read_config_files
      @global_config = RHC::Vendor::ParseConfig.new(@global_config_path) if File.exists?(@global_config_path)
      @local_config = RHC::Vendor::ParseConfig.new(File.expand_path(@local_config_path)) if File.exists?(@local_config_path)
    rescue Errno::EACCES => e
      raise Errno::EACCES.new("Could not open config file: #{e.message}")
    end

    def set_defaults
      @defaults = RHC::Vendor::ParseConfig.new()
      @global_config = nil
      @local_config = nil
      @opts_config = nil # config file passed in the options
      @opts  = RHC::Vendor::ParseConfig.new() # option switches that override config file
      @default_proxy = nil
      @env_config = RHC::Vendor::ParseConfig.new()

      @defaults.add('libra_server', 'openshift.redhat.com')
      @env_config.add('libra_server', ENV['LIBRA_SERVER']) if ENV['LIBRA_SERVER']
      #
      # Config paths... /etc/openshift/express.conf or $GEM/conf/express.conf -> ~/.openshift/express.conf
      #
      @conf_name = 'express.conf'
      @home_dir = File.expand_path("~")
      @home_conf_path = File.join(@home_dir, '.openshift')
      @local_config_path = File.join(@home_conf_path, @conf_name)

      # config path passed in on the command line
      @opts_config_path = nil

      # authoritive config path
      # this can be @local_config_path or @opts_config_path
      # @opts_config_path trumps
      # this is used to determine where config options should be written to
      # when a script modifies the config such as in rhc setup
      @config_path = @local_config_path

      @ssh_priv_key_file_path = "#{@home_dir}/.ssh/id_rsa"
      @ssh_pub_key_file_path = "#{@home_dir}/.ssh/id_rsa.pub"

      @_linux_cfg = '/etc/openshift/' + @conf_name
      @global_config_path = @_linux_cfg
    end

    # used for tests
    def home_dir=(home_dir)
      @home_dir=home_dir
      @home_conf_path = File.join(@home_dir, '.openshift')
      @local_config_path = File.join(@home_conf_path, @conf_name)
      @local_config = nil
      @local_config = RHC::Vendor::ParseConfig.new(File.expand_path(@local_config_path)) if File.exists?(@local_config_path)
      @ssh_priv_key_file_path = "#{@home_dir}/.ssh/id_rsa"
      @ssh_pub_key_file_path = "#{@home_dir}/.ssh/id_rsa.pub"
    end

    def [](key)
      raise KeyError("Please use RHC::Config.password to access the password config") if key == "password"

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

    # password is not allowed in config files and can only be passed on comman line
    def password=(password)
      @opts.add('password', password)
    end

    def password
      @opts['password']
    end

    def set_local_config(confpath, must_exist=true)
      begin
        @local_config_path = File.expand_path(confpath)
        @config_path = @local_config_path if @opts_config_path.nil?
        @local_config = RHC::Vendor::ParseConfig.new(@local_config_path)
      rescue Errno::EACCES => e
        if must_exist
          raise Errno::EACCES.new "Could not open config file: #{e.message}"
        end
      end
    end

    def set_opts_config(confpath)
      begin
        @opts_config_path = File.expand_path(confpath)
        @config_path = @opts_config_path
        @opts_config = RHC::Vendor::ParseConfig.new(@opts_config_path) if File.exists?(@opts_config_path)
      rescue Errno::EACCES => e
        raise Errno::EACCES.new "Could not open config file: #{e.message}"
      end
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

    def has_global_config?
      !@global_config.nil?
    end

    def has_local_config?
      !@local_config.nil?
    end

    def has_opts_config?
      !@opts_config.nil?
    end

    def should_run_ssh_wizard?
      not File.exists? @ssh_priv_key_file_path
    end

    ##
    # config_path
    #
    # authoritive configuration path
    # this is used to determine where config options should be written to
    # when a script modifies the config such as in rhc setup
    def config_path
      @config_path
    end

    def local_config_path
      @local_config_path
    end

    def home_conf_path
      @home_conf_path
    end

    def home_dir
      @home_dir
    end

    def ssh_pub_key_file_path
      @ssh_pub_key_file_path
    end

    def default_rhlogin
      get_value('default_rhlogin')
    end

    def default_proxy
      #
      # Check for proxy environment
      #
      if @default_proxy.nil?
        if ENV['http_proxy']
          if ENV['http_proxy']!~/^(\w+):\/\// then
            ENV['http_proxy']="http://" + ENV['http_proxy']
          end
          proxy_uri=URI.parse(ENV['http_proxy'])
          @default_proxy = Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
        else
          @default_proxy = Net::HTTP
        end
      end
      @default_proxy
    end
  end
end
