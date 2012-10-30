require 'rhc-common'
require 'rhc/helpers'
require 'rhc/ssh_key_helpers'
require 'highline/system_extensions'
require 'net/ssh'
require 'fileutils'
require 'socket'

module RHC
  class Wizard
    include HighLine::SystemExtensions
    include RHC::Helpers
    include RHC::SSHKeyHelpers

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
      if @libra_server.nil?
        @libra_server = config['libra_server']
        # if not set, set to default
        @libra_server = @libra_server ?  @libra_server : "openshift.redhat.com"
      end
      @config.config_user opts.rhlogin if opts && opts.rhlogin
      @debug = opts.debug if opts.respond_to? :debug
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
      paragraph do
        say "Starting Interactive Setup for OpenShift's command line interface"
      end

      paragraph do
        say "It looks like you have not configured or used OpenShift " \
            "client tools on this computer. " \
            "We'll help you configure the client tools with a few quick questions. " \
            "You can skip this in the future by copying your configuration files to other machines you use to manage your OpenShift account:"
      end

      paragraph do
        say "#{@config_path}"
        say "#{RHC::Config.home_dir}/.ssh/"
      end

      true
    end

    def login_stage
      # get_password adds an extra untracked newline so set :bottom to -1
      section(:top => 1, :bottom => -1) do
        if @config.has_opts? && @config.opts_login
          @username = @config.opts_login
          say "Using #{@username}, which was given on the command line"
        else
          @username = ask("To connect to #{@libra_server} enter your OpenShift login (email or Red Hat login id): ") do |q|
            q.default = RHC::Config.default_rhlogin
          end
        end

        @password = RHC::Config.password
        @password = RHC::get_password if @password.nil?
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
          say "Created local config file: " + @config_path
          say "The #{File.basename(@config_path)} file contains user configuration, and can be transferred to different computers."
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
        ssh_pub_key_file_path = generate_ssh_key_ruby()
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
        pubkey_default_name = find_unique_key_name(
          :keys => @ssh_keys,
          :base => pubkey_base_name,
          :max_length => RHC::DEFAULT_MAX_LENGTH
        )
        
        paragraph do
          key_name =  ask("Provide a name for this key: ") do |q|
            q.default = pubkey_default_name
            q.validate = lambda { |p| RHC::check_key(p) }
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
      max  = opts[:max_length] || RHC::DEFAULT_MAX_LENGTH # in rhc-common.rb
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
        paragraph do
          say "We will now check to see if you have the necessary client tools installed."
        end
        generic_unix_install_check
      end
      true
    end

    def config_namespace_stage
      paragraph do
        say "Checking for your namespace ... "
        domains = @rest_client.domains
        if domains.length == 0
          say "not found"
          ask_for_namespace
        else
          say "found namespace:"
          domains.each { |d| say "    #{d.id}" }
        end
      end

      true
    end

    def show_app_info_stage
      section do
        say "Checking for applications ... "
      end
      
      apps = @rest_client.domains.inject([]) do |list, domain|
        list += domain.applications
      end
      
      if !apps.nil? and !apps.empty?
        section(:bottom => 1) do
          say "found"
          apps.each do |app|
            if app.app_url.nil? && app.u
              say "    * #{app.name} - no public url (you need to add a namespace)"
            else
              say "    * #{app.name} - #{app.app_url}"
            end
          end
        end
      else
        section(:bottom => 1) { say "none found" }
        paragraph do
          say "Run 'rhc app create' to create your first application.\n\n"
          say "Below is a list of the types of application you can create: \n"

          application_types = @rest_client.find_cartridges :type => "standalone"
          application_types.sort {|a,b| a.name <=> b.name }.each do |cart|
            say "    * #{cart.name} - rhc app create <app name> #{cart.name}"
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
            q.validate  = lambda{ |p| RHC::check_namespace p }
            q.responses[:not_valid]    = 'The namespace value must contain only letters and/or numbers (A-Za-z0-9):'
            q.responses[:ask_on_error] = ''
          end
        end
      end
    end

    def generic_unix_install_check(show_action=true)
      section(:top => 1) { say "Checking for git ... " } if show_action
      if has_git?
        section(:bottom => 1) { say "found" }
      else
        section(:bottom => 1) { say "needs to be installed" }
        paragraph do
          say "Automated installation of client tools is not supported for " \
              "your platform. You will need to manually install git for full " \
              "OpenShift functionality."
        end
      end
    end

    def windows_install
      # Finding windows executables is hard since they can get installed
      # in non standard directories.  Punt on this for now and simply
      # print out urls and some instructions
      say <<EOF
In order to fully interact with OpenShift you will need to install and configure a git client if you have not already done so.

Documentation for installing other tools you will need for OpenShift can be found at https://#{@libra_server}/app/getting_started#install_client_tools

We recommend these free applications:

  * Git for Windows - a basic git command line and GUI client https://github.com/msysgit/msysgit/wiki/InstallMSysGit
  * TortoiseGit - git client that integrates into the file explorer http://code.google.com/p/tortoisegit/

EOF
    end

    def git_version_exec
      `git --version 2>&1`
    end

    def has_git?
      git_version_exec
      $?.success?
    rescue
      false
    end
    
    def debug?
      @debug
    end
  end

  class RerunWizard < Wizard
    def initialize(config, login=nil)
      super(config, login)
    end

    def greeting_stage
      paragraph do
        say "Starting Interactive Setup for OpenShift's command line interface"
      end

      paragraph do
        say "We'll help get you setup with just a couple of questions. " \
            "You can skip this in the future by copying your config's around:"
      end

      paragraph do
        say "    #{@config_path}"
        say "    #{RHC::Config.home_dir}/.ssh/"
      end

      true
    end

    def create_config_stage
      if File.exists? @config_path
        backup = "#{@config_path}.bak"
        paragraph do
          say "Configuration file #{@config_path} already exists, " \
              "backing up to #{backup}"
        end
        FileUtils.cp(@config_path, backup)
        FileUtils.rm(@config_path)
      end
      super
      true
    end

    def finalize_stage
      paragraph do
        say "Thank you for setting up your system.  You can rerun this at any time " \
            "by calling 'rhc setup'."
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
