require 'yaml'
require 'fileutils'
require 'rhc/helpers'
require 'rhc/server_helpers'

module RHC
  class Server
    include RHC::ServerHelpers
    attr_accessor :hostname, :nickname, :login 
    attr_accessor :use_authorization_tokens, :insecure, :timeout
    attr_accessor :ssl_version, :ssl_client_cert_file, :ssl_ca_file
    attr_accessor :default

    def self.from_yaml_hash(hash)
      hash.symbolize_keys!
      Server.new(hash.delete(:hostname), hash)
    end

    def initialize(hostname, args={})
      @hostname = RHC::Servers.to_host(hostname)
      @nickname = args[:nickname]
      @login = args[:login]
      @use_authorization_tokens = RHC::Helpers.to_boolean(args[:use_authorization_tokens], true)
      @insecure = RHC::Helpers.to_boolean(args[:insecure], true)
      @timeout = Integer(args[:timeout]) if args[:timeout].present?
      @ssl_version = args[:ssl_version]
      @ssl_client_cert_file = args[:ssl_client_cert_file]
      @ssl_ca_file = args[:ssl_ca_file]
      @default = args[:default]
    end

    def default?
      !!@default
    end

    def designation
      @nickname || @hostname
    end

    def to_yaml_hash
      {}.tap do |h| 
        instance_variables.each do |k| 
          h[k.to_s.delete('@')] = instance_variable_get(k)
        end
      end.reject{|k, v| v.nil? || k == 'default'}.inject({}){|h, (k, v)| h[k] = v.is_a?(String) ? v.to_s : v; h }
    end

    def to_config
      RHC::Vendor::ParseConfig.new.tap do |config| 
        h = to_yaml_hash
        h['default_rhlogin'] = h.delete('login')
        h['libra_server'] = h.delete('hostname')
        h.each{|k, v| config.add(k, v)}
      end
    end

    def to_s
      @nickname ? "#{@nickname} (#{@hostname})" : @hostname
    end

    def <=>(other)
      designation <=> other.designation
    end
  end

  class Servers
    include RHC::ServerHelpers
    attr_reader :servers

    def initialize(config=nil)
      @servers ||= load || []
      sync_from_config(config)
    end

    def reload(config=nil)
      @servers = load || []
      sync_from_config(config)
      self
    end

    def path
      File.join(RHC::Config.home_dir, '.openshift', "#{ENV['OPENSHIFT_SERVERS'].presence || 'servers'}.yml")
    end

    def present?
      File.exists?(path)
    end

    def self.to_host(hostname)
      uri = RHC::Helpers.to_uri(hostname)
      uri.scheme == 'https' && uri.port == URI::HTTPS::DEFAULT_PORT ? uri.host : hostname
    end

    def add(hostname, args={})
      raise RHC::ServerHostnameExistsException.new(hostname) if hostname_exists?(hostname)
      raise RHC::ServerNicknameExistsException.new(args[:nickname]) if args[:nickname] && nickname_exists?(args[:nickname])

      args[:nickname] = suggest_server_nickname(Servers.to_host(hostname)) unless args[:nickname].present?

      Server.new(hostname, args).tap{ |server| @servers << server }
    end

    def update(server, args={})
      find(server).tap do |s|
        args.each do |k, v|
          s.send("#{k}=", v) unless v.nil?
        end
      end
    end

    def add_or_update(hostname, args={})
      update(hostname, args) rescue add(hostname, args)
    end

    def remove(server)
      @servers.delete(find(server))
    end

    def list
      @servers || []
    end

    def find(server)
      exists?(server).tap{|s| raise RHC::ServerNotConfiguredException.new(server) unless s }
    end

    def nickname_exists?(nickname)
      list.select{|s| s.nickname.present? && s.nickname == nickname}.first
    end

    def hostname_exists?(hostname)
      hostname = Servers.to_host(hostname)
      list.select{|s| s.hostname == hostname}.first
    end

    def exists?(server)
      hostname_exists?(server) || nickname_exists?(server)
    end

    def default
      list.select(&:default?).first || list.first
    end

    def sync_from_config(config)
      unless config.nil? || !config.has_configs_from_files?
        o = config.to_options
        add_or_update(
          o[:server], 
          :login                    => o[:rhlogin], 
          :use_authorization_tokens => o[:use_authorization_tokens],
          :insecure                 => o[:insecure],
          :timeout                  => o[:timeout],
          :ssl_version              => o[:ssl_version],
          :ssl_client_cert_file     => o[:ssl_client_cert_file],
          :ssl_ca_file              => o[:ssl_ca_file])
        list.each{|server| server.default = server.hostname == o[:server]}
      end
    end

    def save!
      FileUtils.mkdir_p File.dirname(path)
      File.open(path, 'w') do |c| 
        c.puts list.collect{|s| {'server' => s.to_yaml_hash}}.to_yaml
      end
      self
    end

    def backup
      FileUtils.cp(path, "#{path}.bak") if File.exists? path
    end

    protected
      def load
        (YAML.load_file(path) || [] rescue []).collect do |e|
          Server.from_yaml_hash e['server']
        end
      end

      def suggest_server_nickname(hostname)
        suggestion = (case hostname
        when openshift_online_server_regex
          'online'
        when /^(.*)\.#{openshift_online_server.gsub(/\./, '\.')}$/i
          $1
        else
          'server' + ((list.compact.map{|i| i.match(/^server(\d+)$/)}.compact.map{|i| i[1]}.map(&:to_i).max + 1).to_s rescue '1')
        end)
        s = nickname_exists?(suggestion)
        s.present? && s.hostname != hostname ? nil : suggestion
      end
  end
end