require 'commander/user_interaction'
require 'rhc/version'
require 'rhc/config'
require 'rhc/output_helpers'
require 'rbconfig'

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

    extend self

    MAX_RETRIES = 7
    DEFAULT_DELAY_THROTTLE = 2.0

    def disable_deprecated?
      # 1) default for now is false
      # 2) when releasing a 1.0 beta flip this to true
      # 3) all deprecated aliases should be removed right before 1.0
      disable = false

      env_disable = ENV['DISABLE_DEPRECATED']
      disable = true if env_disable == '1'

      disable
    end

    def decode_json(s)
      RHC::Vendor::OkJson.decode(s)
    end

    def date(s)
      now = Date.today
      d = datetime_rfc3339(s)
      if now.year == d.year
        return d.strftime('%l:%M %p').strip if now.yday == d.yday
        d.strftime('%b %d %l:%M %p')
      else
        d.strftime('%b %d, %Y %l:%M %p')
      end
    rescue ArgumentError
      "Unknown date"
    end

    def datetime_rfc3339(s)
      DateTime.strptime(s, '%Y-%m-%dT%H:%M:%S%z')
      # Replace with d = DateTime.rfc3339(s)
    end

    #
    # Web related requests
    #

    def user_agent
      "rhc/#{RHC::VERSION::STRING} (ruby #{RUBY_VERSION}; #{RUBY_PLATFORM})#{" (API #{RHC::Rest::API_VERSION})" rescue ''}"
    end

    #
    # Global config
    #

    global_option '-l', '--rhlogin LOGIN', "OpenShift login"
    global_option '-p', '--password PASSWORD', "OpenShift password"
    global_option '-d', '--debug', "Turn on debugging", :hide => true

    global_option '--server NAME', String, 'An OpenShift server hostname (default: openshift.redhat.com)'
    global_option '-k', '--insecure', "Allow insecure SSL connections.  Potential security risk.", :hide => true

    OptionParser.accept(SSLVersion = Class.new){ |s| OpenSSL::SSL::SSLContext::METHODS.find{ |m| m.to_s.downcase == s.downcase } or raise OptionParser::InvalidOption.new(nil, "The provided SSL version '#{s}' is not valid. Supported values: #{OpenSSL::SSL::SSLContext::METHODS.map(&:to_s).map(&:downcase).join(', ')}") }
    global_option '--ssl-version VERSION', SSLVersion, "The version of SSL to use", :hide => true 
    global_option '--ssl-ca-file FILE', "An SSL certificate CA file (may contain multiple certs)", :hide => true do |value|
      debug certificate_file(value)
    end
    global_option '--ssl-client-cert-file FILE', "An SSL x509 client certificate file", :hide => true do |value|
      debug certificate_file(value)
    end

    global_option('--timeout SECONDS', Integer, 'The timeout for operations') do |value|
      abort(color("Timeout must be a positive integer",:red)) unless value > 0
    end
    global_option '--noprompt', "Suppress the interactive setup wizard from running before a command", :hide => true
    global_option '--config FILE', "Path of a different config file", :hide => true
    global_option '--mock', "Run in mock mode", :hide => true do
      #:nocov:
      require 'rhc/rest/mock'
      RHC::Rest::Mock.start
      #:nocov:
    end

    def openshift_server
      (options.server rescue nil) || ENV['LIBRA_SERVER'] || "openshift.redhat.com"
    end
    def openshift_online_server?
      openshift_server =~ /openshift.redhat.com$/i
    end
    def openshift_url
      "https://#{openshift_server}"
    end

    def client_from_options(opts)
      # rest-client doesn't accept ssl_version, see https://github.com/archiloque/rest-client/pull/140
      #OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ssl_version] = options.ssl_version.to_s if options.ssl_version
      RHC::Rest::Client.new({
          :server => openshift_server,
          :debug => options.debug,
          :timeout => options.timeout,
        }.merge!(ssl_options).merge!(opts))
    end

    def ssl_options
      {
        :ssl_version => options.ssl_version,
        :client_cert => certificate_file(options.ssl_client_cert),
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

    #
    # Output helpers
    #

    def debug(msg)
      $stderr.puts "DEBUG: #{msg}" if debug?
    end
    def debug?
      false
    end

    def deprecated_command(correct,short = false)
      deprecated("This command is deprecated. Please use '#{correct}' instead.",short)
    end

    def deprecated_option(deprecated,new)
      deprecated("The option '#{deprecated}' is deprecated. Please use '#{new}' instead")
    end

    def deprecated(msg,short = false)
      HighLine::use_color = false if windows? # handle deprecated commands that does not start through highline

      info = " For porting and testing purposes you may switch this %s to %s by setting the DISABLE_DEPRECATED environment variable to %d.  It is not recommended to do so in a production environment as this option will be removed in a future release."
      msg << info unless short

      raise DeprecatedError.new(msg % ['an error','a warning',0]) if disable_deprecated?

      warn "Warning: #{msg}\n" % ['a warning','an error',1]
    end

    @@indent = 0
    @@last_line_open = false
    def say(msg, *args)
      output = if Hash[*args][:stderr]
          $stderr
        else
          separate_blocks
          $terminal.instance_variable_get(:@output)
        end

      Array(msg).each do |statement|
        statement = statement.to_str
        next unless statement.present?

        template  = ERB.new(statement, nil, "%")
        statement = template.result(binding)

        statement = wrap(statement) unless @wrap_at.nil?
        statement = page_print(statement) unless @page_at.nil?

        output.print(' ' * @@indent * INDENT) unless @@last_line_open

        @@last_line_open = 
          if statement[-1, 1] == " " or statement[-1, 1] == "\t"
            output.print(statement)
            output.flush
          else
            output.puts(statement)
          end
      end

      msg
    end

    [:ask, :agree].each do |sym|
      define_method(sym) do |*args, &block|
        separate_blocks
        super(*args, &block)
      end
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

    def color(s, color)
      $terminal.color(s, color)
    end

    def pluralize(count, s)
      count == 1 ? "#{count} #{s}" : "#{count} #{s}s"
    end

    # given an array of arrays "items", construct an array of strings that can
    # be used to print in tabular form.
    def table(items, opts={}, &block)
      items = items.map &block if block_given?
      widths = []
      items.each do |item|
        item.each_with_index do |s, i|
          item[i] = s.to_s
          widths[i] = [widths[i] || 0, item[i].length].max
        end
      end
      align = opts[:align] || []
      join = opts[:join] || ' '
      if opts[:header]
        sep = opts[:separator] || "="
        ary = Array.new(opts[:header].length)
        items.unshift ary.each_with_index {|obj, idx| ary[idx] = sep.to_s * (widths[idx] || 1)}
        items.unshift(opts[:header])
      end
      items.map do |item|
        item.each_with_index.map{ |s,i| s.send((align[i] == :right ? :rjust : :ljust), widths[i], ' ') }.join(join).rstrip
      end
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
        :uuid           => "UUID",
        :current_scale  => "Current",
        :scales_from    => "Minimum",
        :scales_to      => "Maximum",
        :url            => "URL",
        :ssh_string     => "SSH",
        :connection_info => "Connection URL",
        :gear_profile   => "Gear Size"
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

    #def tee(&block)
    #  original = [$stdout, $stderr]
    #  $stdout, $stderr = (tees = original.map{ |io| StringTee.new(io) })
    #  yield
    #ensure
    #  $stdout, $stderr = original
    #  tees.each(&:close_write).map(&:string)
    #end

    def header(s,opts = {}, &block)
      say [s, "="*s.length]
      if block_given?
        indent &block
      end
    end

    INDENT = 2
    def indent(&block)
      @@indent += 1
      begin
        yield
      ensure
        @@indent -= 1
      end
    end

    ##
    # section
    #
    # highline helper mixin which correctly formats block of say and ask
    # output to have correct margins.  section remembers the last margin
    # used and calculates the relitive margin from the previous section.
    # For example:
    #
    # section(bottom=1) do
    #   say "Hello"
    # end
    #
    # section(top=1) do
    #   say "World"
    # end
    #
    # Will output:
    #
    # > Hello
    # >
    # > World 
    #
    # with only one newline between the two.  Biggest margin wins.
    #
    # params:
    #  top - top margin specified in lines
    #  bottom - bottom margin specified in line
    #
    @@margin = nil
    def section(params={}, &block)
      top = params[:top] || 0
      bottom = params[:bottom] || 0

      # the first section cannot take a newline
      top = 0 unless @@margin
      @@margin = [top, @@margin || 0].max

      value = block.call

      say "\n" if @@last_line_open
      @@margin = [bottom, @@margin].max

      value
    end

    ##
    # paragraph
    #
    # highline helper which creates a section with margins of 1, 1
    #
    def paragraph(&block)
      section(:top => 1, :bottom => 1, &block)
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
      dns.getresources(host, Resolv::DNS::Resource::IN::A).any?
      # :nocov:
    end

    def hosts_file_contains?(host)
      # :nocov:
      resolver = Resolv::Hosts.new
      resolver.getaddress host
    rescue Resolv::ResolvError
      # :nocov:
    end

    # Run a command and export its output to the user.  Output is not capturable
    # on all platforms.
    def run_with_tee(cmd)
      status, stdout, stderr = nil

      if windows?
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

    private

      def separate_blocks
        if (@@margin ||= 0) > 0 && !@@last_line_open
          $terminal.instance_variable_get(:@output).print "\n" * @@margin
          @@margin = 0
        end
      end
  end
end
