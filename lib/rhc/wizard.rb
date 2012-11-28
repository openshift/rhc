require 'rhc/helpers'
require 'rhc/ssh_helpers'
require 'rhc/git_helpers'
require 'highline/system_extensions'
require 'fileutils'
require 'socket'

module RHC
  class Wizard
    include HighLine::SystemExtensions
    include RHC::Helpers
    include RHC::SSHHelpers
    include RHC::GitHelpers

    DEFAULT_MAX_LENGTH = 16

    STAGES = [:greeting_stage,
              :login_stage,
              :create_config_stage,
              :config_ssh_key_stage,
              :upload_ssh_key_stage,
              :install_client_tools_stage,
              :config_namespace_stage,
              :show_app_info_stage,
              :finalize_stage]
    def stages
      STAGES
    end

    def initialize(config, opts=nil)
      @config = config
      @config_path = config.config_path
      @libra_server = (opts && opts.server) || config['libra_server'] || "openshift.redhat.com"
      @config.config_user opts.rhlogin if opts && opts.rhlogin
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
        # FIXME: cleanup if we fail
        debug "Running #{stage}"
        if (self.send stage).nil?
          return nil
        end
      end
      true
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
      # get_password adds an extra untracked newline so set :bottom to -1
      paragraph do
        if @config.has_opts? && @config.opts_login
          @username = @config.opts_login
          say "Using #{@username}"
        else
          @username = ask("Login to #{@libra_server}: ") do |q|
            q.default = RHC::Config.default_rhlogin
          end
        end

        @password = @opts.password if @opts
        @password = ask("Password: ") { |q| q.echo = '*' } if @password.nil?
      end

      # instantiate a REST client that stages can use
      end_point = "https://#{@libra_server}/broker/rest/api"
      @rest_client = RHC::Rest::Client.new(end_point, @username, @password, @debug)
      
      # confirm that the REST client can connect
      return false unless @rest_client.user

      true
    end

    def create_config_stage
      if !File.exists? @config_path
        FileUtils.mkdir_p File.dirname(@config_path)
        File.open(@config_path, 'w') do |file|
          file.puts <<EOF
# Default user login
default_rhlogin='#{@username}'

# Server API
libra_server = '#{@libra_server}'
EOF

        end

        paragraph do
          say "Creating #{@config_path} to store your configuration"
        end

        true
      end

      # Read in @config_path now that it exists (was skipped before because it did
      # not exist
      RHC::Config.set_local_config(@config_path)
    end

    def config_ssh_key_stage
      if RHC::Config.should_run_ssh_wizard?
        paragraph do
          say "No SSH keys were found. We will generate a pair of keys for you."
        end
        ssh_pub_key_file_path = generate_ssh_key_ruby
        paragraph do
          say "    Created: #{ssh_pub_key_file_path}\n\n"
        end
      end
      true
    end

    # return true if the account has the public key defined by
    # RHC::Config::ssh_pub_key_file_path
    def ssh_key_uploaded?
      @ssh_keys ||= @rest_client.sshkeys
      @ssh_keys.any? { |k| k.fingerprint == fingerprint_for_default_key }
    end

    def existing_keys_info
      return unless @ssh_keys
      # TODO: This ERB format is shared with RHC::Commands::Sshkey; should be refactored
      @ssh_keys.inject("Current Keys: \n") do |result, key|
        erb = ::RHC::Helpers.ssh_key_display_format
        result += format(key, erb)
      end
    end

    def get_preferred_key_name
      paragraph do
        say "You can enter a name for your key, or leave it blank to use the default name. " \
            "Using the same name as an existing key will overwrite the old key."
      end
      key_name = 'default'

      if @ssh_keys.empty?
        paragraph do
          say <<-DEFAULT_KEY_UPLOAD_MSG
Since you do not have any keys associated with your OpenShift account,
your new key will be uploaded as the 'default' key
          DEFAULT_KEY_UPLOAD_MSG
        end
      else
        section(:top => 1) { say existing_keys_info }

        key_fingerprint = fingerprint_for_default_key
        unless key_fingerprint
          paragraph do
            say <<-CONFIG_KEY_INVALID
Your ssh public key at #{RHC::Config.ssh_pub_key_file_path} is invalid or unreadable.
The setup can not continue until you manually remove or fix both of your
public and private keys id_rsa keys.
            CONFIG_KEY_INVALID
          end
          return nil
        end
        hostname = Socket.gethostname.gsub(/\..*\z/,'')
        username = @username ? @username.gsub(/@.*/, '') : ''
        pubkey_base_name = "#{username}#{hostname}".gsub(/[^A-Za-z0-9]/,'').slice(0,16)
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
      say "type: %s\ncontent: %s\nfingerprint: %s" % [type, content, fingerprint_for_default_key]

      if !@ssh_keys.empty? && @ssh_keys.any? { |k| k.name == key_name }
        say "Key with the name #{key_name} already exists. Updating... "
        key = @rest_client.find_key(key_name)
        key.update(type, content)
      else
        say "Uploading key '#{key_name}' from #{RHC::Config::ssh_pub_key_file_path}"
        @rest_client.add_key key_name, content, type
      end
      
      true
    end

    def upload_ssh_key_stage
      return true if ssh_key_uploaded?

      upload = false
      section do
        upload = agree "Your public ssh key must be uploaded to the OpenShift server.  Would you like us to upload it for you? (yes/no) "
      end

      if upload
        upload_ssh_key
      else
        paragraph do
          say "You can upload your ssh key at a later time using the 'rhc sshkey' command"
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
        domains = @rest_client.domains
        if domains.length == 0
          warn "none"
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

        apps = @rest_client.domains.map(&:applications).flatten

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
            application_types = @rest_client.find_cartridges :type => "standalone"
            say table(application_types.sort {|a,b| a.display_name <=> b.display_name }.map do |cart|
              [' ', cart.display_name, "rhc app create <app name> #{cart.name}"]
            end).join("\n")
          end
        end
      end
      true
    end

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
      paragraph do
        if namespace.nil? or namespace.chomp.length == 0
          say "Skipping! You may create a namespace using 'rhc domain create'"
          return true
        end

        begin
          domain = @rest_client.add_domain(namespace)

          say "Your domain name '#{domain.id}' has been successfully created"
        rescue RHC::Rest::ValidationException => e
          say e.message
          return false
        end
      end
      true
    end

    def ask_for_namespace
      paragraph do
        say "Your namespace is unique to your account and is the suffix of the " \
            "public URLs we assign to your applications. You may configure your " \
            "namespace here or leave it blank and use 'rhc domain create' to " \
            "create a namespace later.  You will not be able to create " \
            "applications without first creating a namespace."
      end

      # Ask for a namespace at least once, configure the namespace if a valid,
      # non-blank string is provided.
      namespace  = nil
      first_pass = true
      while first_pass or !config_namespace namespace do
        first_pass = false
        paragraph do
          namespace = ask "Please enter a namespace or leave this blank if you wish to skip this step:" do |q|
            #q.validate  = lambda{ |p| RHC::check_namespace p }
            #q.responses[:not_valid]    = 'The namespace value must contain only letters and/or numbers (A-Za-z0-9):'
            q.responses[:ask_on_error] = ''
          end
        end
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

Documentation for installing other tools you will need for OpenShift can be found at https://#{@libra_server}/app/getting_started#install_client_tools

We recommend these free applications:

  * Git for Windows - a basic git command line and GUI client https://github.com/msysgit/msysgit/wiki/InstallMSysGit
  * TortoiseGit - git client that integrates into the file explorer http://code.google.com/p/tortoisegit/

EOF
    end

    def debug?
      @debug
    end
  end

  class RerunWizard < Wizard
    def initialize(config, login=nil)
      super(config, login)
    end

    def create_config_stage
      if File.exists? @config_path
        backup = "#{@config_path}.bak"
        paragraph do
          say "Saving previous configuration to #{backup}"
        end
        FileUtils.cp(@config_path, backup)
        FileUtils.rm(@config_path)
      end
      super
      true
    end

    def finalize_stage
      section(:top => 1, :bottom => 0) do
        say "Your client tools are now configured."
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

    def initialize(rest_client)
      @rest_client = rest_client
      super RHC::Config
    end
  end
end
