require 'rhc/helpers'
require 'rhc/ssh_helpers'
require 'rhc/git_helpers'
require 'highline/system_extensions'
require 'fileutils'
require 'socket'

module RHC
  class Wizard
    include HighLine::SystemExtensions

    DEFAULT_MAX_LENGTH = 16

    STAGES = [:greeting_stage,
              :login_stage,
              :create_config_stage,
              :config_ssh_key_stage,
              :upload_ssh_key_stage,
              :install_client_tools_stage,
              :setup_test_stage,
              :config_namespace_stage,
              :show_app_info_stage,
              :finalize_stage]
    def stages
      STAGES
    end

    attr_reader :rest_client

    #
    # Running the setup wizard may change the contents of opts and config if
    # the create_config_stage completes successfully.
    #
    def initialize(config=RHC::Config.new, opts=Commander::Command::Options.new)
      @config = config
      @options = opts
      @debug = opts.debug if opts
    end

    # Public: Runs the setup wizard to make sure ~/.openshift and ~/.ssh are correct
    #
    # Examples
    #
    #  wizard.run()
    #  # => true
    #
    # Returns nil on failure or true on success
    def run
      stages.each do |stage|
        debug "Running #{stage}"
        if self.send(stage).nil?
          return nil
        end
      end
      true
    end

    protected
      include RHC::Helpers
      include RHC::SSHHelpers
      include RHC::GitHelpers
      attr_reader :config, :options
      attr_accessor :auth, :user

      def openshift_server
        options.server || config['libra_server'] || "openshift.redhat.com"
      end

      def new_client_for_options
        client_from_options({
          :auth => auth,
        })
      end

      def auth
        @auth ||= RHC::Auth::Basic.new(options)
      end

      def username
        auth.send(:username)
      end
      def password
        auth.send(:password)
      end

    private

    def greeting_stage
      info "OpenShift Client Tools (RHC) Setup Wizard"

      paragraph do
        say "This wizard will help you upload your SSH keys, set your application namespace, and check that other programs like Git are properly installed."
      end

      true
    end

    def login_stage
      say "Using #{options.rhlogin} to login to #{openshift_server}" if options.rhlogin

      self.rest_client = new_client_for_options

      begin
        rest_client.api
      rescue RHC::Rest::CertificateVerificationFailed => e
        debug "Certificate validation failed: #{e.reason}"
        unless options.insecure
          if RHC::Rest::SelfSignedCertificate === e
            warn "The server's certificate is self-signed, which means that a secure connection can't be established to '#{openshift_server}'."
          else
            warn "The server's certificate could not be verified, which means that a secure connection can't be established to '#{openshift_server}'."
          end
          if openshift_online_server?
            paragraph{ warn "This may mean that a server between you and OpenShift is capable of accessing information sent from this client.  If you wish to continue without checking the certificate, please pass the -k (or --insecure) option to this command." }
            return
          else
            paragraph{ warn "You may bypass this check, but any data you send to the server could be intercepted by others." }
            return unless agree "Connect without checking the certificate? (yes|no): "
            options.insecure = true
            self.rest_client = new_client_for_options
            retry
          end
        end
      end

      self.user = rest_client.user
      true
    end

    def create_config_stage
      if File.exists? config.path
        backup = "#{@config.path}.bak"
        paragraph{ say "Saving previous configuration to #{backup}" }
        FileUtils.cp(config.path, backup)
        FileUtils.rm(config.path)
      end

      paragraph{ say "Creating #{config.path} to store your configuration" }

      changed = Commander::Command::Options.new(options)
      changed.rhlogin = username
      changed.password = password

      FileUtils.mkdir_p File.dirname(config.path)
      config.save!(changed)
      options.__replace__(changed)

      true
    end

    def config_ssh_key_stage
      if config.should_run_ssh_wizard?
        paragraph{ say "No SSH keys were found. We will generate a pair of keys for you." }

        ssh_pub_key_file_path = generate_ssh_key_ruby
        paragraph{ say "    Created: #{ssh_pub_key_file_path}" }
      end
      true
    end

    # return true if the account has the public key defined by
    # RHC::Config::ssh_pub_key_file_path
    def ssh_key_uploaded?
      @ssh_keys ||= rest_client.sshkeys
      @ssh_keys.any? { |k| k.fingerprint == fingerprint_for_default_key }
    end

    def existing_keys_info
      return unless @ssh_keys
      indent{ @ssh_keys.each{ |key| paragraph{ display_key(key) } } }
    end

    def get_preferred_key_name
      key_name = 'default'

      if @ssh_keys.empty?
        paragraph do
          info "Since you do not have any keys associated with your OpenShift account, "\
              "your new key will be uploaded as the 'default' key."
        end
      else
        paragraph do
          say "You can enter a name for your key, or leave it blank to use the default name. " \
              "Using the same name as an existing key will overwrite the old key."
        end

        paragraph { existing_keys_info }

        key_fingerprint = fingerprint_for_default_key
        unless key_fingerprint
          paragraph do
            say "Your ssh public key at #{RHC::Config.ssh_pub_key_file_path} is invalid or unreadable. "\
                "Setup can not continue until you manually remove or fix your "\
                "public and private keys id_rsa keys."
          end
          return nil
        end

        hostname = Socket.gethostname.gsub(/\..*\z/,'')
        userkey = username ? username.gsub(/@.*/, '') : ''
        pubkey_base_name = "#{userkey}#{hostname}".gsub(/[^A-Za-z0-9]/,'').slice(0,16)
        default_name = find_unique_key_name(
          :keys => @ssh_keys,
          :base => pubkey_base_name,
          :max_length => DEFAULT_MAX_LENGTH
        )

        paragraph do
          key_name = ask("Provide a name for this key: ") do |q|
            q.default = default_name
            q.validate = /^[0-9a-zA-Z]*$/
            q.responses[:not_valid]    = 'Your key name must be letters and numbers only.'
          end
        end
      end

      key_name
    end
    
    # given the base name and the maximum length,
    # find a name that does not clash with what is in opts[:keys]
    def find_unique_key_name(opts)
      keys = opts[:keys] || @ssh_keys
      base = opts[:base] || 'default'
      max  = opts[:max_length] || DEFAULT_MAX_LENGTH
      key_name_suffix = 1
      candidate = base
      while @ssh_keys.detect { |k| k.name == candidate }
        candidate = base.slice(0, max - key_name_suffix.to_s.length) +
          key_name_suffix.to_s
        key_name_suffix += 1
      end
      candidate
    end

    def upload_ssh_key
      key_name = get_preferred_key_name
      return false unless key_name

      type, content, comment = ssh_key_triple_for_default_key
      indent do
        say table([['Type:', type], ['Fingerprint:', fingerprint_for_default_key]])
      end

      paragraph do
        if !@ssh_keys.empty? && @ssh_keys.any? { |k| k.name == key_name }
          say "Key with the name #{key_name} already exists. Updating ... "
          key = rest_client.find_key(key_name)
          key.update(type, content)
        else
          say "Uploading key '#{key_name}' from #{RHC::Config::ssh_pub_key_file_path} ... "
          rest_client.add_key key_name, content, type
        end
        success "done"
      end

      true
    end

    def upload_ssh_key_stage
      return true if ssh_key_uploaded?

      upload = paragraph do
        agree "Your public SSH key must be uploaded to the OpenShift server to access code.  Upload now? (yes|no) "
      end

      if upload
        upload_ssh_key
      else
        paragraph do
          info "You can upload your SSH key at a later time using the 'rhc sshkey' command"
        end
      end

      true
    end

    ##
    # Alert the user that they should manually install tools if they are not
    # currently available
    #
    # Unix Tools:
    #  git
    #
    # Windows Tools:
    #  msysgit (Git for Windows)
    #  TortoiseGIT (Windows Explorer integration)
    #
    def install_client_tools_stage
      if windows?
        windows_install
      else
        generic_unix_install_check
      end
      true
    end

    def config_namespace_stage
      paragraph do
        say "Checking your namespace ... "
        domains = rest_client.domains
        if domains.length == 0
          warn "none"

          paragraph do
            say "Your namespace is unique to your account and is the suffix of the " \
                "public URLs we assign to your applications. You may configure your " \
                "namespace here or leave it blank and use 'rhc domain create' to " \
                "create a namespace later.  You will not be able to create " \
                "applications without first creating a namespace."
          end

          ask_for_namespace
        else
          success domains.map(&:id).join(', ')
        end
      end

      true
    end

    def show_app_info_stage
      section do
        say "Checking for applications ... "

        apps = rest_client.domains.map(&:applications).flatten

        if !apps.nil? and !apps.empty?
          success "found #{apps.length}"

          paragraph do
            indent do
              say table(apps.map do |app|
                [app.name, app.app_url]
              end)
            end
          end
        else
          info "none"

          paragraph{ say "Run 'rhc app create' to create your first application." }
          paragraph do
            application_types = rest_client.find_cartridges :type => "standalone"
            say table(application_types.sort {|a,b| a.display_name <=> b.display_name }.map do |cart|
              [' ', cart.display_name, "rhc app create <app name> #{cart.name}"]
            end).join("\n")
          end
        end
        paragraph do
          indent do
            say "You are using #{color(self.user.consumed_gears.to_s, :green)} of #{color(self.user.max_gears.to_s, :green)} total gears" if user.max_gears.is_a? Fixnum
            say "The following gear sizes are available to you: #{self.user.capabilities.gear_sizes.join(', ')}" if user.capabilities.gear_sizes.present?
          end
        end
      end
      true
    end

    def setup_test_stage
      tests_passed = false
      info "Analyzing system (one dot for each test)"
      tests = [
        :test_ssh_quick,
        :test_broker_connectivity,
        :test_server_has_ssh_keys,
        :test_private_key_mode,
        :test_remote_ssh_keys,
        :test_ssh_connectivity
      ]
      tests_passed = tests.all? do |test|
        send(test)
      end
    end
    
    ###
    # tests for setup_test_stage; no code coverage is tested here
    
    # :nocov:
    def ssh_agent_identities
      Net::SSH::Authentication::Agent.connect.identities rescue []
    end
    
    def ssh_agent_keys
      @agent_keys ||= ssh_agent_identities.map { |id| id.comment }
    end
    
    def test_ssh_quick
      hosts = []
      server_keys = []
      
      rest_client.domains.map do |domain|
        domain.applications.each do |app|
          if Net::SSH.configuration_for(app.host)[:keys]
            Net::SSH.configuration_for(app.host)[:keys].map{ |f| server_keys << File.expand_path(f) }
          end
        end
      end

      server_keys ||= server_keys.flatten!.compact!
      report_result (server_keys - ssh_agent_keys).empty?, "SSH keys missing on the server"
    end
    
    def test_broker_connectivity
      # for simple connectivity to the broker, we ensure that the server
      # replied with a list of API versions
      report_result(rest_client.api_version_negotiated, "#{rest_client.url} did not respond with valid data") and
      
      # if the REST client is properly initialized and has #user defined,
      # the authentication was successful
      report_result(rest_client.user, "Authentication as #{rest_client.user.login} failed")
    end
    
    def test_server_has_ssh_keys
      # at least one key is stored on the server
      report_result !rest_client.sshkeys.empty?, "No SSH key is uploaded to the server for #{rest_client.user.login}"
    end

    def test_private_key_mode
      pub_key_file = RHC::Config.ssh_pub_key_file_path
      private_key_file = RHC::Config.ssh_priv_key_file_path
      # we test these only in the context of FakeFS; to avoid displaying 
      # NoMethodError on the console, we basically skip it (and bypass coverage)
      if File.exist?(private_key_file) and defined?(FakeFS) and !File.stat(private_key_file).is_a?(FakeFS::File::Stat)
        report_result (File.exist?(private_key_file) and File.stat(private_key_file).mode.to_s(8) =~ /[4-7]00$/),
          "#{private_key_file} should not be accessible by no one but the user"
      else
        true # wizard should go on
      end
    end
    
    def test_remote_ssh_keys
      # test if the server has the remote key
      server_has_key = rest_client.sshkeys.any? do |k|
        k.fingerprint == fingerprint_for_default_key or
        if ssh_agent_identities
          ssh_agent_identities.map{|agent_key| k.fingerprint == agent_key.fingerprint }
        end
      end
      report_result server_has_key, "Remote server does not have the corresponding SSH key"
    end
    
    def test_ssh_connectivity
      # test connectivity for each app server
      rest_client.domains.each do |dom|
        dom.applications do |app|
          tries = 0
          begin
            ssh = Net::SSH.start(app.host, app.uuid, :timeout => 10)
          rescue Timeout::Error
            if tries < 3
              tries += 1
              retry
            end
          ensure
            report_result(ssh, "Cannot connect to #{app.host}", false)
            ssh.close if ssh
          end
        end
      end
      true # continue
    end
    # :nocov:

    ###
    
    def finalize_stage
      paragraph do
        say "The OpenShift client tools have been configured on your computer.  " \
            "You can run this setup wizard at any time by using the command 'rhc setup' " \
            "We will now execute your original " \
            "command (rhc #{ARGV.join(" ")})"
      end
      true
    end

    def config_namespace(namespace)
      # skip if string is empty
      if namespace.nil? or namespace.chomp.length == 0
        paragraph{ info "You may create a namespace later through 'rhc domain create'" }
        return true
      end

      begin
        domain = rest_client.add_domain(namespace)

        success "Your domain name '#{domain.id}' has been successfully created"
      rescue RHC::Rest::ValidationException => e
        error e.message || "Unknown error during namespace creation."
        return false
      end
      true
    end

    def ask_for_namespace
      # Ask for a namespace at least once, configure the namespace if a valid,
      # non-blank string is provided.
      namespace = nil
      paragraph do
        begin
          namespace = ask "Please enter a namespace (letters and numbers only) |<none>|: " do |q|
            #q.validate  = lambda{ |p| RHC::check_namespace p }
            #q.responses[:not_valid]    = 'The namespace value must contain only letters and/or numbers (A-Za-z0-9):'
            q.responses[:ask_on_error] = ''
          end
        end while !config_namespace(namespace)
      end
    end

    def generic_unix_install_check
      paragraph do 
        say "Checking for git ... "

        if has_git?
          success("found #{git_version}") rescue success('found')
        else
          warn "needs to be installed"

          paragraph do
            say "Automated installation of client tools is not supported for " \
                "your platform. You will need to manually install git for full " \
                "OpenShift functionality."
          end
        end
      end
    end

    def windows_install
      # Finding windows executables is hard since they can get installed
      # in non standard directories.  Punt on this for now and simply
      # print out urls and some instructions
      warn <<EOF

In order to fully interact with OpenShift you will need to install and configure a git client if you have not already done so.

Documentation for installing other tools you will need for OpenShift can be found at https://openshift.redhat.com/community/developers/install-the-client-tools

We recommend these free applications:

  * Git for Windows - a basic git command line and GUI client https://github.com/msysgit/msysgit/wiki/InstallMSysGit
  * TortoiseGit - git client that integrates into the file explorer http://code.google.com/p/tortoisegit/

EOF
    end

    def debug?
      @debug
    end

    protected
      attr_writer :rest_client
  end

  class RerunWizard < Wizard

    def finalize_stage
      section :top => 1 do
        success "Your client tools are now configured."
      end
      true
    end
  end

  class SSHWizard < Wizard
    STAGES = [:config_ssh_key_stage,
              :upload_ssh_key_stage]
    def stages
      STAGES
    end

    def initialize(rest_client, config, options)
      self.rest_client = rest_client
      super config, options
    end
  end
end
