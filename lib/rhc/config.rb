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

  #
  # Responsible for encapsulating the loading and retrieval of OpenShift
  # configuration files and converting them to commandline option 
  # equivalents.  It also provides the converse option - converting a set
  # of commandline options back into a config file.
  #
  # In general, the values stored in the config should be identical (require
  # little or no type conversion) to their option form.  As new global 
  # options are added, only this class should have to change to persist that
  # option.
  #
  # During normal use, a new Config object should load the appropriate
  # settings and those settings should be converted into commandline option
  # defaults.
  #
  # TODO: Encapsulate config writing to the home location
  # TODO: Allow the config object to initialized with a path
  # TODO: Remove deprecated methods, remove extra sources.
  #
  class Config
    include ConfigEnv

    # Option name     [config_key      type           comment_string_for_config]
    #                  if nil, == key  nil == string  won't be written to file if nil
    OPTIONS = {
      :server =>      ['libra_server', nil, 'The server to connect to'],
      :rhlogin =>     ['default_rhlogin', nil, 'The OpenShift login name'],
      :password =>    nil,
      :timeout =>     [nil, :integer, 'The default timeout for network operations'],
      :ssl_client_cert_file => [nil, :path_to_file, 'A client certificate file for use with your server'],
      :ssl_ca_file => [nil, :path_to_file, 'A file containing CA one or more certificates'],
      :insecure =>    [nil, :boolean, "If true, certificate errors will be ignored.\nWARNING: This may allow others to eavesdrop on your communication with OpenShift."]
    }

    def self.options_to_config(options)
      OPTIONS.inject([]) do |arr, (name, opts)|
        opts ||= []
        next arr unless opts[2]
        value = options[name]
        arr.concat(opts[2].each_line.to_a.map(&:strip).map{ |s| "# #{s}" })
        arr << "#{value.nil? ? '#' : ''}#{opts[0] || name}=#{self.type_to_config(opts[1], value)}"
        arr << ""
        arr
      end.join("\n")
    end

    def self.type_to_config(type, value)
      case type
      when :integer, :boolean
        value.nil? ? "<#{type}>" : value
      else
        "\"#{value.nil? ? "<#{type || 'string'}>" : value}\""
      end
    end

    # DEPRECATED - will be removed when old commands are gone
    def self.default
      @default ||= RHC::Config.new
    end

    # DEPRECATED - will be removed when old commands are gone
    def self.method_missing(method, *args, &block)
      if default.respond_to?(method)
        default.send(method, *args, &block)
      else
        raise NoMethodError, method
      end
    end

    # DEPRECATED - will be removed when old commands are gone
    def self.initialize
      @default = nil
      default
    end

    # DEPRECATED - will be removed when old commands are gone
    def initialize
      set_defaults
    end

    # DEPRECATED - will be removed when old commands are gone
    def read_config_files
      load_config_files
    end

    # DEPRECATED - will be removed when old commands are gone
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

    def to_options
      OPTIONS.inject({}) do |h, (name, opts)|
          opts = Array(opts)
          value = self[opts[0] || name.to_s]
          if value
            h[name] = case opts[1]
                      when :integer
                        Integer(value)
                      when :boolean
                        !!(value =~ /^\s*(y|yes|1|t|true)\s*$/i)
                      else
                        value
                      end
          end
          h
        end
    end

    def save!(options)
      File.open(path, 'w'){ |f| f.puts self.class.options_to_config(options) }
      @opts, @opts_config, @local_config, @global_config = nil
      load_config_files
      self
    end

    def [](key)
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

    # DEPRECATED - will be removed when old commands are gone
    def get_value(key)
      self[key]
    end

    # DEPRECATED - underlying value and command option needs to be migrated to login
    def username
      self['default_rhlogin']
    end

    # DEPRECATED - will be removed when old commands are gone
    def set_local_config(conf_path, must_exist=true)
      conf_path = File.expand_path(conf_path)
      @config_path = conf_path if @opts_config_path.nil?
      @local_config = RHC::Vendor::ParseConfig.new(conf_path)
    rescue Errno::EACCES => e
      raise Errno::EACCES.new "Could not open config file: #{e.message}" if must_exist
    end

    # DEPRECATED - needs to be renamed to something cleaner
    def set_opts_config(conf_path)
      @opts_config_path = File.expand_path(conf_path)
      @config_path = @opts_config_path
      @opts_config = RHC::Vendor::ParseConfig.new(@opts_config_path) if File.exists?(@opts_config_path)
    rescue Errno::EACCES => e
      raise Errno::EACCES.new "Could not open config file: #{e.message}"
    end

    # DEPRECATED - will be removed when old commands are gone
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

    # DEPRECATED - may be made private
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

    # DEPRECATED - should be moved to Helpers
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
    def path
      config_path
    end

    def home_dir
      RHC::Config.home_dir
    end

    def home_conf_path
      home_conf_dir
    end

    # DEPRECATED - will be removed when old commands are gone
    def default_rhlogin
      get_value('default_rhlogin')
    end

    # DEPRECATED - will be removed when old commands are gone
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

    # DEPRECATED - will be removed when old commands are gone
    def using_proxy?
      default_proxy.instance_variable_get(:@is_proxy_class) || false
    end

    # DEPRECATED - will be removed when old commands are gone
    def proxy_vars
      Hash[[:address,:user,:pass,:port].map do |x|
        [x,default_proxy.instance_variable_get("@proxy_#{x}")]
      end]
    end

    private
      # Allow mocking of the home dir
      def self.home_dir
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
