require 'commander/user_interaction'
require 'rhc/version'
require 'rhc/config'
require 'rhc/output_helpers'
require 'rhc/server_helpers'
require 'rbconfig'
require 'csv'
require 'resolv'

OptionParser.accept(URI) {|s,| URI.parse(s) if s}

module RHC

  module Helpers
    private
      def self.global_option(*args, &block)
        RHC::Commands.global_option *args, &block
      end
  end

  module Helpers

    # helpers always have Commander UI available
    include Commander::UI
    include Commander::UI::AskForClass
    include RHC::OutputHelpers
    include RHC::ServerHelpers

    extend self

    def decode_json(s)
      RHC::Vendor::OkJson.decode(s)
    end

    def system_path(path)
      return path.gsub(File::SEPARATOR, File::ALT_SEPARATOR) if File.const_defined?('ALT_SEPARATOR') and File::ALT_SEPARATOR.present?
      path
    end

    PREFIX = %W(TB GB MB KB B).freeze

    def human_size( s )
      return "unknown" unless s
      s = s.to_f
      i = PREFIX.length - 1
      while s > 500 && i > 0
        i -= 1
        s /= 1000
      end
      ((s > 9 || s.modulo(1) < 0.1 ? '%d' : '%.1f') % s) + ' ' + PREFIX[i]
    end

    def date(s)
      return nil unless s.present?
      now = Date.today
      d = datetime_rfc3339(s).to_time
      if now.year == d.year
        return d.strftime('%l:%M %p').strip if now.yday == d.yday
        d.strftime('%b %d %l:%M %p')
      else
        d.strftime('%b %d, %Y %l:%M %p')
      end
    rescue ArgumentError
      "Unknown date"
    end

    def distance_of_time_in_words(from_time, to_time = 0)
      from_time = from_time.to_time if from_time.respond_to?(:to_time)
      to_time = to_time.to_time if to_time.respond_to?(:to_time)
      distance_in_minutes = (((to_time - from_time).abs)/60).round
      distance_in_seconds = ((to_time - from_time).abs).round

      case distance_in_minutes
        when 0..1
          return distance_in_minutes == 0 ?
                 "less than 1 minute" :
                 "#{distance_in_minutes} minute"

        when 2..44           then "#{distance_in_minutes} minutes"
        when 45..89          then "about 1 hour"
        when 90..1439        then "about #{(distance_in_minutes.to_f / 60.0).round} hours"
        when 1440..2519      then "about 1 day"
        when 2520..43199     then "#{(distance_in_minutes.to_f / 1440.0).round} days"
        when 43200..86399    then "about 1 month"
        else
          "about #{(distance_in_minutes.to_f / 43200.0).round} months"
      end
    end

    def datetime_rfc3339(s)
      DateTime.strptime(s, '%Y-%m-%dT%H:%M:%S%z')
      # Replace with d = DateTime.rfc3339(s)
    end

    #
    # Web related requests
    #

    def user_agent
      "rhc/#{RHC::VERSION::STRING} (ruby #{RUBY_VERSION}; #{RUBY_PLATFORM})#{" (API #{RHC::Rest::Client::CLIENT_API_VERSIONS})"}"
    end

    #
    # Global config
    #

    global_option '-l', '--rhlogin LOGIN', "OpenShift login"
    global_option '-p', '--password PASSWORD', "OpenShift password"
    global_option '--token TOKEN', "An authorization token for accessing your account."

    global_option '-d', '--debug', "Turn on debugging", :hide => true

    global_option '--server HOSTNAME', String, 'An OpenShift server hostname (default: openshift.redhat.com)'
    global_option '-k', '--insecure', "Allow insecure SSL connections.  Potential security risk.", :hide => true

    global_option '--header HEADER', String,"Custom header to pass to server", :hide => true
    global_option '--limit INTEGER', Integer, "Maximum number of simultaneous operations to execute.", :hide => true
    global_option '--raw', "Do not format the output from the requested operations.", :hide => true
    global_option '--always-prefix', "Include the gear prefix on all output from the server.", :hide => true

    OptionParser.accept(SSLVersion = Class.new){ |s| parse_ssl_version(s) }
    global_option '--ssl-version VERSION', SSLVersion, "The version of SSL to use", :hide => true do |value|
      raise RHC::Exception, "You are using an older version of the httpclient gem which prevents the use of --ssl-version.  Please run 'gem update httpclient' to install a newer version (2.2.6 or newer)." unless HTTPClient::SSLConfig.method_defined? :ssl_version
    end
    global_option '--ssl-ca-file FILE', "An SSL certificate CA file (may contain multiple certs)", :hide => true do |value|
      debug certificate_file(value)
    end
    global_option '--ssl-client-cert-file FILE', "An SSL x509 client certificate file", :hide => true do |value|
      debug certificate_file(value)
    end
    global_option '--ssl-client-key-file FILE', "An RSA client certificate key", :hide => true do |value|
      debug certificate_key(value)
    end

    global_option('--timeout SECONDS', Integer, 'The timeout for operations') do |value|
      raise RHC::Exception, "Timeout must be a positive integer" unless value > 0
    end
    global_option '--always-auth', "Always use authentication when making OpenShift API requests.", :hide => true
    global_option '--noprompt', "Suppress all interactive operations command", :hide => true do
      $terminal.page_at = nil
    end
    global_option '--config FILE', "Path of a different config file (default: #{system_path("~/.openshift/express.conf")})", :hide => true
    global_option '--clean', "Ignore any saved configuration options", :hide => true
    global_option '--mock', "Run in mock mode", :hide => true do
      #:nocov:
      require 'rhc/rest/mock'
      RHC::Rest::Mock.start
      #:nocov:
    end

    ROLES = {'view' => 'viewer', 'edit' => 'editor', 'admin' => 'administrator'}
    OptionParser.accept(Role = Class.new) do |s|
      s.downcase!
      (ROLES.has_key?(s) && s) or
        raise OptionParser::InvalidOption.new(nil, "The provided role '#{s}' is not valid. Supported values: #{ROLES.keys.join(', ')}")
    end

    OptionParser.accept(CertificateFile = Class.new) {|s| certificate_file(s); s}
    OptionParser.accept(CertificateKey = Class.new) {|s| certificate_key(s); s}

    def role_name(s)
      ROLES[s.downcase]
    end

    def to_host(s)
      s =~ %r(^http(?:s)?://) ? URI(s).host : s
    end

    def to_uri(s)
      begin
        URI(s =~ %r(^http(?:s)?://) ? s : "https://#{s}")
      rescue URI::InvalidURIError
        raise RHC::InvalidURIException.new(s)
      end
    end

    def ssh_string(ssh_url)
      return nil if ssh_url.blank?
      uri = URI.parse(ssh_url)
      "#{uri.user}@#{uri.host}"
    rescue => e
      RHC::Helpers.debug_error(e)
      ssh_url
    end

    def ssh_string_parts(ssh_url)
      uri = URI.parse(ssh_url)
      [uri.host, uri.user]
    end

    def token_for_user
      return options.token if options.token
      return nil unless options.use_authorization_tokens

      token_store_user_key = if options.ssl_client_cert_file
        certificate_fingerprint(options.ssl_client_cert_file)
      else
        options.rhlogin
      end

      return nil if token_store_user_key.nil?
      token_store.get(token_store_user_key, options.server)
    end

    def parse_headers(headers)
      Hash[
        Array(headers).map do |header|
          key, value = header.split(/: */, 2)
          [key, value || ""] if key.presence
        end.compact
      ]
    end

    def client_from_options(opts)
      RHC::Rest::Client.new({
          :url => openshift_rest_endpoint.to_s,
          :debug => options.debug,
          :headers => parse_headers(options.header),
          :timeout => options.timeout,
          :warn => BOUND_WARNING,
          :api_always_auth => options.always_auth
        }.merge!(ssl_options).merge!(opts))
    end

    def ssl_options
      {
        :ssl_version => options.ssl_version,
        :ca_file => options.ssl_ca_file && File.expand_path(options.ssl_ca_file),
        :verify_mode => options.insecure ? OpenSSL::SSL::VERIFY_NONE : nil,
      }.delete_if{ |k,v| v.nil? }
    end

    def certificate_file(file)
      file && OpenSSL::X509::Certificate.new(IO.read(File.expand_path(file)))
    rescue => e
      debug e
      raise OptionParser::InvalidOption.new(nil, "The certificate '#{file}' cannot be loaded: #{e.message} (#{e.class})")
    end

    def certificate_fingerprint(file)
      Digest::SHA1.hexdigest(certificate_file(file).to_der)
    end

    def certificate_key(file)
      file && OpenSSL::PKey::RSA.new(IO.read(File.expand_path(file)))
    rescue => e
      debug e
      raise OptionParser::InvalidOption.new(nil, "The RSA key '#{file}' cannot be loaded: #{e.message} (#{e.class})")
    end

    def parse_ssl_version(version)
      OpenSSL::SSL::SSLContext::METHODS.find{ |m| m.to_s.downcase == version.to_s.downcase } or raise OptionParser::InvalidOption.new(nil, "The provided SSL version '#{version}' is not valid. Supported values: #{OpenSSL::SSL::SSLContext::METHODS.map(&:to_s).map(&:downcase).join(', ')}") unless version.nil?
    end

    #
    # Output helpers
    #

    def interactive?
      $stdin.tty? and $stdout.tty? and not options.noprompt
    end

    def debug(*args)
      $terminal.debug(*args)
    end
    def debug_error(*args)
      $terminal.debug_error(*args)
    end
    def debug?
      $terminal.debug?
    end

    def exec(cmd)
      output = Kernel.send(:`, cmd)
      [$?.exitstatus, output]
    end

    def disable_deprecated?
      ENV['DISABLE_DEPRECATED'] == '1'
    end

    def deprecated_command(correct, short=false)
      deprecated("This command is deprecated. Please use '#{correct}' instead.", short)
    end

    def deprecated(msg,short = false)
      raise DeprecatedError.new(msg % ['an error','a warning',0]) if disable_deprecated?
      warn "Warning: #{msg}\n" % ['a warning','an error',1]
    end

    #
    # By default, agree should take a single character in interactive
    #
    def agree(*args, &block)
      #args.push(interactive?.presence) if args.length == 1
      block = lambda do |q|
        q.validate = /\A(?:y|yes|n|no)\Z/i
      end unless block_given?
      super *args, &block
    end

    def confirm_action(question)
      return if options.confirm
      return if !options.noprompt && paragraph{ agree "#{question} (yes|no): " }
      raise RHC::ConfirmationError
    end

    def success(msg, *args)
      say color(msg, :green), *args
    end

    def info(msg, *args)
      say color(msg, :cyan), *args
    end

    def warn(msg, *args)
      say color(msg, :yellow), *args
    end

    def error(msg, *args)
      say color(msg, :red), *args
    end

    # OVERRIDE: Replaces default commander behavior
    def color(item, *args)
      unless (options.raw rescue false)
        if item.is_a? Array
          item.map{ |i| $terminal.color(i, *args) }
        else
          $terminal.color(item, *args)
        end
      else 
        item
      end
    end

    [:pager, :indent, :paragraph, :section, :header, :table, :table_args].each do |sym|
      define_method(sym) do |*args, &block|
        $terminal.send(sym, *args, &block)
      end
    end

    def pluralize(count, s)
      count == 1 ? "#{count} #{s}" : "#{count} #{s}s"
    end

    # This will format table headings for a consistent look and feel
    #   If a heading isn't explicitly defined, it will attempt to look up the parts
    #   If those aren't found, it will capitalize the string
    def table_heading(value)
      # Set the default proc to look up undefined values
      headings = Hash.new do |hash,key|
        items = key.to_s.split('_')
        # Look up each piece individually
        hash[key] = items.length > 1 ?
          # Recusively look up the heading for the parts
          items.map{|x| headings[x.to_sym]}.join(' ') :
          # Capitalize if this part isn't defined
          items.first.capitalize
      end

      # Predefined headings (or parts of headings)
      headings.merge!({
        :creation_time  => "Created",
        :expires_in_seconds => "Expires In",
        :uuid            => "ID",
        :id              => 'ID',
        :current_scale   => "Current",
        :scales_from     => "Minimum",
        :scales_to       => "Maximum",
        :gear_sizes      => "Allowed Gear Sizes",
        :consumed_gears  => "Gears Used",
        :max_gears       => "Gears Allowed",
        :max_domains     => "Domains Allowed",
        :compact_members => "Members",
        :gear_info       => "Gears",
        :plan_id         => "Plan",
        :url             => "URL",
        :ssh_string      => "SSH",
        :connection_info => "Connection URL",
        :gear_profile    => "Gear Size",
        :visible_to_ssh? => 'Available',
        :downloaded_cartridge_url => 'From',
        :auto_deploy     => 'Deployment',
        :sha1            => 'SHA1',
        :ref             => 'Git Reference',
        :use_authorization_tokens => 'Use Auth Tokens',
        :ssl_ca_file     => 'SSL Cert CA File',
        :ssl_version     => 'SSL Version',
        :ssl_client_cert_file => 'SSL x509 Client Cert File',
        :ssl_client_key_file  => 'SSL x509 Client Key File',
        :zones           => 'Available Zones'
      })

      headings[value]
    end

    class StringTee < StringIO
      attr_reader :tee
      def initialize(other)
        @tee = other
        super()
      end
      def <<(buf)
        tee << buf
        super
      end
    end

    ##
    # results
    #
    # highline helper which creates a paragraph with a header
    # to distinguish the final results of a command from other output
    #
    def results(&block)
      section(:top => 1, :bottom => 0) do
        say "RESULT:"
        yield
      end
    end

    # Platform helpers
    def jruby? ; RUBY_PLATFORM =~ /java/i end
    def windows? ; RUBY_PLATFORM =~ /win(32|dows|ce)|djgpp|(ms|cyg|bcc)win|mingw32/i end
    def unix? ; !jruby? && !windows? end
    def mac? ; RbConfig::CONFIG['host_os'] =~ /^darwin/ end

    #
    # Check if host exists
    #
    def host_exists?(host)
      # :nocov:
      # Patch for BZ840938 to support Ruby 1.8 on machines without /etc/resolv.conf
      dns = Resolv::DNS.new((Resolv::DNS::Config.default_config_hash || {}))
      resources = dns.getresources(host, Resolv::DNS::Resource::IN::A)
      debug("Checking for #{host} from Resolv::DNS: #{resources.inspect}") if debug?
      resources.present?
      # :nocov:
    end

    def hosts_file_contains?(host)
      with_tolerant_encoding do
        begin
          resolver = Resolv::Hosts.new
          result = resolver.getaddress host
          debug("Checking for #{host} from Resolv::Hosts: #{result.inspect}") if debug?
          result
        rescue => e
          debug "Application could not be resolved through Hosts file:  #{e.message}(#{e.class})\n #{e.backtrace.join("\n ")}\n Attempting DNS resolution."
        end
      end
    end

    def with_tolerant_encoding(&block)
      # :nocov:
      if RUBY_VERSION.to_f >= 1.9
        orig_default_internal = Encoding.default_internal
        Encoding.default_internal = 'ISO-8859-1'
      else
        orig_default_kcode = $KCODE
        $KCODE = 'N'
      end
      yield
    ensure
      if RUBY_VERSION.to_f >= 1.9
        Encoding.default_internal = orig_default_internal
      else
        $KCODE = orig_default_kcode
      end
      # :nocov:
    end

    # Run a command and export its output to the user.  Output is not capturable
    # on all platforms.
    def run_with_tee(cmd)
      status, stdout, stderr = nil

      if windows? || jruby?
        #:nocov: TODO: Test block
        system(cmd)
        status = $?.exitstatus
        #:nocov:
      else
        stdout, stderr = [$stdout, $stderr].map{ |t| StringTee.new(t) }
        status = Open4.spawn(cmd, 'stdout' => stdout, 'stderr' => stderr, 'quiet' => true)
        stdout, stderr = [stdout, stderr].map(&:string)
      end

      [status, stdout, stderr]
    end

    def env_var_regex_pattern
      /^([a-zA-Z_][\w]*)=(.*)$/
    end

    def collect_env_vars(items)
      return nil if items.blank?

      env_vars = []

      Array(items).each do |item|
        if match = item.match(env_var_regex_pattern)
          name, value = match.captures
          env_vars << RHC::Rest::EnvironmentVariable.new({ :name => name, :value => value })
        elsif File.file? item
          File.readlines(item).each do |line|
            if match = line.match(env_var_regex_pattern)
              name, value = match.captures
              env_vars << RHC::Rest::EnvironmentVariable.new({ :name => name, :value => value })
            end
          end
        end
      end
      env_vars
    end

    def to_boolean(s, or_nil=false)
      return nil if s.nil? && or_nil
      s.is_a?(String) ? !!(s =~ /^(true|t|yes|y|1)$/i) : s
    end

    # split spaces but preserve sentences between quotes
    def split_path(s, keep_quotes=false)
      keep_quotes ? s.split(/\s(?=(?:[^"]|"[^"]*")*$)/) : CSV::parse_line(s, :col_sep => ' ')
    end

    def discover_windows_executables(&block)
      #:nocov:
      if RHC::Helpers.windows?

        base_path = []
        guessing_locations = []

        # Look for the base path int the ProgramFiles env var...
        if program_files = ENV['ProgramFiles']; program_files.present? && File.exists?(program_files)
          base_path << program_files
        end

        # ... and in win32ole drives (drive root or Program Files)
        begin
          require 'win32ole'
          WIN32OLE.new("Scripting.FileSystemObject").tap do |file_system|
            file_system.Drives.each do |drive|
              base_path << [
                "#{drive.DriveLetter}:\\Program Files (x86)",
                "#{drive.DriveLetter}:\\Program Files",
                "#{drive.DriveLetter}:\\Progra~1",
                "#{drive.DriveLetter}:"
              ]
            end
          end
        rescue
        end

        # executables array from block
        executable_groups = []
        base_path.flatten.uniq.each do |base|
          executable_groups << yield(base)
        end

        # give proper priorities
        unless executable_groups.empty?
          length = executable_groups.first.length
          for i in 1..length do
            executable_groups.each do |group|
              guessing_locations << group[i - 1]
            end
          end
        end

        guessing_locations.flatten.uniq.select {|cmd| File.exist?(cmd) && File.executable?(cmd)}
      else
        []
      end
      #:nocov:
    end

    def exe?(executable)
      ENV['PATH'].split(File::PATH_SEPARATOR).any? do |directory|
        File.executable?(File.join(directory, executable.to_s))
      end
    end

    BOUND_WARNING = self.method(:warn).to_proc
  end
end
