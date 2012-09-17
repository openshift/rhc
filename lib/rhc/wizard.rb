require 'rhc-common'
require 'rhc/helpers'
require 'rhc/ssh_key_helpers'
require 'highline/system_extensions'
require 'net/ssh'
require 'fileutils'

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

    def initialize(config)
      @config = config
      @config_path = config.config_path
      if @libra_server.nil?
        @libra_server = config['libra_server']
        # if not set, set to default
        @libra_server = @libra_server ?  @libra_server : "openshift.redhat.com"
      end
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
        @username = ask("To connect to #{@libra_server} enter your OpenShift login (email or Red Hat login id): ") do |q|
          q.default = RHC::Config.default_rhlogin
        end

        @password = RHC::Config.password
        @password = RHC::get_password if @password.nil?
      end

      # Confirm username / password works:
      user_info = RHC::get_user_info(@libra_server, @username, @password, RHC::Config.default_proxy, true)

      # instantiate a REST client that stages can use
      # TODO: use only REST calls in the wizard
      end_point = "https://#{@libra_server}/broker/rest/api"
      @rest_client = RHC::Rest::Client.new(end_point, @username, @password)

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

    # For Net::SSH versions (< 2.0.11) that does not have
    # Net::SSH::KeyFactory.load_public_key, we drop to shell to get
    # the key's fingerprint
    def ssh_keygen_fallback(path)
      `ssh-keygen -lf #{path} 2>&1`.split(' ')[1]

      if $?.exitstatus != 0
        error "Unable to compute SSH public key finger print for #{path}"
      end
    end

    def fingerprint_for_default_key
      fingerprint_for RHC::Config::ssh_pub_key_file_path
    end

    def fingerprint_for(key)
      Net::SSH::KeyFactory.load_public_key(key).fingerprint
    rescue NoMethodError => e
      ssh_keygen_fallback key
      return nil
    rescue OpenSSL::PKey::PKeyError, Net::SSH::Exception => e
      error e.message
      return nil
    end

    # return true if the account has the public key defined by
    # RHC::Config::ssh_pub_key_file_path
    def ssh_key_uploaded?
      @ssh_keys ||= @rest_client.sshkeys
      @ssh_keys.any? { |k| k.fingerprint == fingerprint_for_default_key }
    end

    def existing_keys_info
      result = "Current Keys: \n"
      # TODO: This ERB format is shared with RHC::Commands::Sshkey; should be refactored
      @ssh_keys.each do |key|
        erb = ERB.new <<-FORMAT
       Name: <%= key.name %>
       Type: <%= key.type %>
Fingerprint: <%= key.fingerprint %>

      FORMAT
        result += format(key, erb)
      end

      result
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
        pubkey_default_name = key_fingerprint[0, 12].gsub(/[^0-9a-zA-Z]/,'')
        paragraph do
          key_name =  ask("Provide a name for this key: ") do |q|
            q.default = pubkey_default_name
            q.validate = lambda { |p| RHC::check_key(p) }
          end
        end
      end

      key_name
    end

    def upload_ssh_key
      key_name = get_preferred_key_name
      return false unless key_name

      if !@ssh_keys.empty? && @ssh_keys.any? { |k| k.name == key_name }
        say "Key with the name #{key_name} already exists. Deleting... "
        @rest_client.delete_key key_name
      end

      say "Uploading key '#{key_name}' from #{RHC::Config::ssh_pub_key_file_path}"

      #### TODO: This portion is duplicated in RHC::Rest::Client
      ####       Should be refactored to a helper
      begin
        file = File.open RHC::Config.ssh_pub_key_file_path
      rescue Errno::ENOENT => e
        raise ::RHC::KeyFileNotExistentException.new("File '#{key}' does not exist.")
      rescue Errno::EACCES => e
        raise ::RHC::KeyFileAccessDeniedException.new("Access denied to '#{key}'.")
      end
      type, content, comment = file.gets.chomp.split
      ####
      say "type: %s\ncontent: %s\n" % [type, content]

      @rest_client.add_key key_name, content, type
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
    # Attempts install various tools if they aren't currently installed on the
    # users system.  If we can't automate the install, alert the user that they
    # should manually install them
    #
    # On Unix we rely on PackageKit (which mostly just covers modern Linux flavors
    # such as Fedora, Suse, Debian and Ubuntu). On Windows we will give instructions
    # and links for the tools they should install
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
        # we use command line tools for dbus since the dbus gem is not cross
        # platform and compiles itself on the host system when installed
        paragraph do
          say "We will now check to see if you have the necessary client tools installed."
        end
        if has_dbus_send?
          package_kit_install
        else
          generic_unix_install_check
        end
      end
      true
    end

    def config_namespace_stage
      paragraph do
        say "Checking for your namespace ... "
        user_info = RHC::get_user_info(@libra_server, @username, @password, RHC::Config.default_proxy, true)
        domains = user_info['user_info']['domains']
        if domains.length == 0
          say "not found"
          ask_for_namespace
        else
          say "found namespace:"
          domains.each { |d| say "    #{d['namespace']}" }
        end
      end

      true
    end

    def show_app_info_stage
      section do
        say "Checking for applications ... "
      end
      user_info = RHC::get_user_info(@libra_server, @username, @password, RHC::Config.default_proxy, true)
      apps = user_info['app_info']
      if !apps.nil? and !apps.empty?
        section(:bottom => 1) do
          say "found"
          apps.each do |app_name, app_info|
            app_url = nil
            unless user_info['user_info']['domains'].empty?
              app_url = "http://#{app_name}-#{user_info['user_info']['domains'][0]['namespace']}.#{user_info['user_info']['rhc_domain']}/"
            end

            if app_url.nil?
              say "    * #{app_name} - no public url (you need to add a namespace)"
            else
              say "    * #{app_name} - #{app_url}"
            end
          end
        end
      else
        section(:bottom => 1) { say "none found" }
        paragraph do
          say "Below is a list of the types of application " \
              "you can create: "

          application_types = RHC::get_cartridges_list @libra_server, RHC::Config.default_proxy
          application_types.each do |cart|
            say "    * #{cart} - rhc app create -t #{cart} -a <app name>"
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

    def dbus_send_exec(name, service, obj_path, iface, stringafied_params, wait_for_reply)
      # :nocov: dbus_send_exec is not safe to run on a test system
      method = "#{iface}.#{name}"
      print_reply = ""
      print_reply = "--print-reply" if wait_for_reply

      cmd = "dbus-send --session #{print_reply} --type=method_call \
            --dest=#{service} #{obj_path} #{method} #{stringafied_params}"
      `cmd 2>&1`
      # :nocov:
    end

    def dbus_send_session_method(name, service, obj_path, iface, stringafied_params, wait_for_reply=true)
      output = dbus_send_exec(name, service, obj_path, iface, stringafied_params, wait_for_reply)
      raise output if output.start_with?('Error') and !$?.success?

      # parse the output
      results = []
      output.split('\n').each_with_index do |line, i|
        if i != 0 # discard first line
          param_type, value = line.chomp.split(" ", 2)

          case param_type
          when "boolean"
            results << (value == 'true')
          when "string"
            results << value
          else
            say "unknown type #{param_type} - treating as string"
            results << value
          end
        end
      end

      if results.length == 0
        return nil
      elsif results.length == 1
        return results[0]
      else
        return results
      end
    end

    ##
    # calls package kit methods using dbus_send
    #
    # name - method name
    # iface - either 'Query' or 'Modify'
    # stringafied_params - string of params in the format of dbus-send
    #  e.g. "int32:10 string:'hello world'"
    #
    def package_kit_method(name, iface, stringafied_params, wait_for_reply=true)
      service = "org.freedesktop.PackageKit"
      obj_path = "/org/freedesktop/PackageKit"
      full_iface = "org.freedesktop.PackageKit.#{iface}"
      dbus_send_session_method name, service, obj_path, full_iface, stringafied_params, wait_for_reply
    end
    def package_kit_git_installed?
      package_kit_method('IsInstalled', 'Query', 'string:git string:')
    end

    def package_kit_install
      section(:top => 1) do
        say "Checking for git ... "
      end

      begin
        # double check due to slight differences in older platforms
        if has_git? or package_kit_git_installed?
          section(:bottom => 1) { say "found" }
        else
          section(:bottom => 1) { say "needs to be installed" }
          install = false
          section do
            install = agree "Would you like to install git with the system installer? (yes/no) "
          end
          if install
            package_kit_method('InstallPackageNames', 'Modify', 'uint32:0 array:string:"git" string:', false)
            paragraph do
              say "You may safely continue while the installer is running or " \
                  "you can wait until it has finished.  Press any key to continue:"
              get_character
            end
          end
        end
      rescue
        generic_unix_install_check false
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

    def has_dbus_send?
      bus = ENV['DBUS_SESSION_BUS_ADDRESS']
      exe? 'dbus-send' and !bus.nil? and bus.length > 0
    end
  end

  class RerunWizard < Wizard
    def initialize(config)
      super
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

    def initialize(username, password)
      @username = username
      @password = password
      super RHC::Config
    end
  end
end
