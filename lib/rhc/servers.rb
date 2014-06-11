require 'yaml'
require 'fileutils'
require 'rhc/helpers'
require 'rhc/server_helpers'

module RHC
  class Server
    include RHC::ServerHelpers
    attr_accessor :hostname, :nickname, :login, :use_authorization_tokens, :insecure, :default

    def self.from_yaml_hash(hash)
      hash.symbolize_keys!
      Server.new(hash.delete(:hostname), hash)
    end

    def initialize(hostname, args={})
      @hostname = RHC::Helpers.to_uri(hostname).host
      @nickname = args[:nickname].nil? && @hostname =~ openshift_online_server_regex ? 'online' : args[:nickname] 
      @login = args[:login]
      @use_authorization_tokens = RHC::Helpers.to_boolean(args[:use_authorization_tokens], true)
      @insecure = RHC::Helpers.to_boolean(args[:insecure], true)
      @default = args[:default]
    end

    def default?
      !!@default
    end

    def designation
      @nickname || @hostname
    end

    def to_yaml_hash
      {}.tap{|h| instance_variables.each{|k| h[k.to_s.delete('@')] = instance_variable_get(k)}}.reject {|k, v| v.nil? || k == 'default'}
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
      [nickname || hostname] <=> [other.nickname || other.hostname]
    end

  end

  class Servers
    include RHC::ServerHelpers
    attr_reader :servers

    def initialize(config=nil)
      @servers ||= load || []
      sync_from_config(config)
    end

    def path
      File.join(RHC::Config.home_dir, '.openshift', "#{ENV['OPENSHIFT_SERVERS'].presence || 'servers'}.yml")
    end

    def present?
      File.exists?(path)
    end

    def to_host(hostname)
      RHC::Helpers.to_uri(hostname).host
    end

    def add(hostname, args={})
      raise RHC::ServerHostnameExistsException.new(hostname) if hostname_exists?(hostname)
      raise RHC::ServerNicknameExistsException.new(args[:nickname]) if args[:nickname] && nickname_exists?(args[:nickname])

      Server.new(hostname, args).tap{ |server| @servers << server }
    end

    def update(server, args={})
      if server = find(server) rescue nil
        args.each do |k, v|
          server.send("#{k}=", v) unless v.nil?
        end
      end
      server
    end

    def add_or_update(hostname, args={})
      update(hostname, args) || add(hostname, args)
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

    def default
      list.select(&:default?).first || list.first
    end

    def sync_from_config(config)
      unless config.nil? || !config.has_configs_from_files?
        o = config.to_options
        add_or_update(
          o[:server], 
          :nickname                 => o[:server] =~ openshift_online_server_regex ? 'online' : nil, 
          :login                    => o[:rhlogin], 
          :use_authorization_tokens => o[:use_authorization_tokens],
          :insecure                 => o[:insecure])
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

      def nickname_exists?(nickname)
        list.select{|s| s.nickname.present? && s.nickname == nickname}.first
      end

      def hostname_exists?(hostname)
        hostname = to_host(hostname)
        list.select{|s| s.hostname == hostname}.first
      end

      def exists?(server)
        hostname_exists?(server) || nickname_exists?(server)
      end
  end
end