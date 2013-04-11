require 'rhc'
require 'fileutils'
require 'socket'

module RHC
  class Wizard
    include HighLine::SystemExtensions

    def self.has_configuration?
      File.exists? RHC::Config.local_config_path
    end

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
      include RHC::CartridgeHelpers
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

      def core_auth
        @core_auth ||= RHC::Auth::Basic.new(options)
      end

      def token_auth
        RHC::Auth::Token.new(options, core_auth, token_store)
      end

      def auth(reset=false)
        @auth = nil if reset
        @auth ||= begin
            if options.token
              token_auth
            else
              core_auth
            end
          end
      end

      def token_store
        @token_store ||= RHC::Auth::TokenStore.new(config.home_conf_path)
      end

      def username
        options.rhlogin || (auth.username if auth.respond_to?(:username))
      end

      def print_dot
        $terminal.instance_variable_get(:@output).print('.')
      end

    private

    # cache SSH keys from the REST client
    def ssh_keys
      @ssh_keys ||= rest_client.sshkeys
    end

    # clear SSH key cache
    def clear_ssh_keys_cache
      @ssh_keys = nil
    end

    def greeting_stage
      info "OpenShift Client Tools (RHC) Setup Wizard"

      paragraph do
        say "This wizard will help you upload your SSH keys, set your application namespace, and check that other programs like Git are properly installed."
      end

      true
    end

    def login_stage
      if token_for_user
        options.token = token_for_user
        say "Using an existing token for #{options.rhlogin} to login to #{openshift_server}"
      elsif options.rhlogin
        say "Using #{options.rhlogin} to login to #{openshift_server}"
      end

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
      options.rhlogin = self.user.login unless username

      if rest_client.supports_sessions? && !options.token && options.create_token != false
        paragraph do
          info "OpenShift can create and store a token on disk which allows to you to access the server without using your password. The key is stored in your home directory and should be kept secret.  You can delete the key at any time by running 'rhc logout'."
          if options.create_token or agree "Generate a token now? (yes|no) "
            say "Generating an authorization token for this client ... "
            token = rest_client.new_session
            options.token = token.token
            self.auth(true).save(token.token)
            self.rest_client = new_client_for_options
            self.user = rest_client.user

            success "lasts #{distance_of_time_in_words(token.expires_in_seconds)}"
          end
        end
      end
      true
    end

    def create_config_stage
      paragraph do
        if File.exists? config.path
          backup = "#{@config.path}.bak"
          FileUtils.cp(config.path, backup)
          FileUtils.rm(config.path)
        end

        say "Saving configuration to #{system_path(config.path)} ... "

        changed = Commander::Command::Options.new(options)
        changed.rhlogin = username
        changed.password = nil
        changed.use_authorization_tokens = options.create_token != false && !changed.token.nil?

        FileUtils.mkdir_p File.dirname(config.path)
        config.save!(changed)
        options.__replace__(changed)

        success "done"
      end

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
      ssh_keys.any? { |k| k.fingerprint == fingerprint_for_default_key }
    end

    def existing_keys_info
      return unless ssh_keys
      indent{ ssh_keys.each{ |key| paragraph{ display_key(key) } } }
    end

    def get_preferred_key_name
      key_name = 'default'

      if ssh_keys.empty?
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
            warn "Your ssh public key at #{system_path(RHC::Config.ssh_pub_key_file_path)} is invalid or unreadable. "\
                "Setup can not continue until you manually remove or fix your "\
                "public and private keys id_rsa keys."
          end
          return nil
        end

        userkey = username ? username.gsub(/@.*/, '') : ''
        pubkey_base_name = "#{userkey}#{hostname.gsub(/\..*\z/,'')}".gsub(/[^A-Za-z0-9]/,'').slice(0,16)
        default_name = find_unique_key_name(
          :keys => ssh_keys,
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
      keys = opts[:keys] || ssh_keys
      base = opts[:base] || 'default'
      max  = opts[:max_length] || DEFAULT_MAX_LENGTH
      key_name_suffix = 1
      candidate = base
      while ssh_keys.detect { |k| k.name == candidate }
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
        if !ssh_keys.empty? && ssh_keys.any? { |k| k.name == key_name }
          clear_ssh_keys_cache
          say "Key with the name #{key_name} already exists. Updating ... "
          key = rest_client.find_key(key_name)
          key.update(type, content)
        else
          clear_ssh_keys_cache
          say "Uploading key '#{key_name}' from #{system_path(RHC::Config::ssh_pub_key_file_path)} ... "
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

        if !applications.nil? and !applications.empty?
          success "found #{applications.length}"

          paragraph do
            indent do
              say table(applications.map do |app|
                [app.name, app.app_url]
              end)
            end
          end
        else
          info "none"

          paragraph{ say "Run 'rhc app create' to create your first application." }
          paragraph do
            say table(standalone_cartridges.sort {|a,b| a.display_name <=> b.display_name }.map do |cart|
              [' ', cart.display_name, "rhc app create <app name> #{cart.name}"]
            end)
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

    # Perform basic tests to ensure that setup is sane
    # search for private methods starting with "test_" and execute them
    # in alphabetical order
    # NOTE: The order itself is not important--the tests should be independent.
    # However, the hash order is unpredictable in Ruby 1.8, and is preserved in
    # 1.9. There are two similar tests that can fail under the same conditions,
    # and this makes the spec results inconsistent between 1.8 and 1.9.
    # Thus, we force an order with #sort to ensure spec passage on both.
    def setup_test_stage
      say "Checking common problems "
      failed = false
      all_test_methods.sort.each do |test|
        begin
          send(test)
          print_dot unless failed
          true
        rescue => e
          say "\n" unless failed
          failed = true
          paragraph{ error e.message }
          false
        end
      end.tap do |pass|
        success(' done') if !failed
      end

      true
    end

    def all_test_methods
      private_methods.select {|m| m.to_s.start_with? 'test_'}
    end

    # cached list of applications needed for test stage
    def applications
      @applications ||= rest_client.domains.map(&:applications).flatten
    end

    ###
    # tests for specific user errors

    def test_private_key_mode
      pub_key_file = RHC::Config.ssh_pub_key_file_path
      private_key_file = RHC::Config.ssh_priv_key_file_path
      if File.exist?(private_key_file)
        unless File.stat(private_key_file).mode.to_s(8) =~ /[4-7]00$/
          raise "Your private SSH key file should be set as readable only to yourself.  Please run 'chmod 600 #{system_path(private_key_file)}'"
        end
      end
      true
    end

    # test connectivity an app
    def test_ssh_connectivity
      return true unless ssh_key_uploaded?

      applications.take(1).each do |app|
        begin
          ssh = Net::SSH.start(app.host, app.uuid, :timeout => 60)
        rescue => e
          raise "An SSH connection could not be established to #{app.host}. Your SSH configuration may not be correct, or the application may not be responding. #{e.message} (#{e.class})"
        ensure
          ssh.close if ssh
        end
      end
      true
    end

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

    def hostname
      Socket.gethostname
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
