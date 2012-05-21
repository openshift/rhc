require 'rhc-common'
require 'helpers'
require 'highline/system_extensions'

# ruby 1.8 -> 1.9 magic
begin
  require 'ftools'
rescue LoadError
  require 'fileutils'
end

module RHC
  class Wizard
    include HighLine::SystemExtensions

    @@stages = [:greeting_stage,
                :login_stage,
                :create_config_stage,
                :config_ssh_key_stage,
                :upload_ssh_key_stage,
                :install_client_tools_stage,
                :finalize_stage]

    def initialize(config_path)
      @config_path = config_path
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
      @@stages.each do |stage|
        # FIXME: cleanup if we fail
        if (self.send stage).nil?
          return nil
        end
      end
      true
    end

    private

    def greeting_stage
      say "\nStarting Interactive Setup for OpenShift's command line interface\n\n"
      say "It looks like you've not used OpenShift on this machine " \
          "before.  We'll help get you setup with just a couple of questions. " \
          "You can skip this in the future by copying your config's around: \n\n"
      say "#{@config_path}"
      say "#{RHC::Config.home_dir}/.ssh/\n\n"

      true
    end

    def login_stage

      @username = ask("To connect to https://openshift.redhat.com enter your OpenShift login (email or Red Hat login id): ")
      @password = RHC::get_password
      @libra_server = get_var('libra_server')
      # Confirm username / password works:
      user_info = RHC::get_user_info(@libra_server, @username, @password, RHC::Config.default_proxy, true)
      true
    end

    def create_config_stage
      if !File.exists? @config_path
        FileUtils.mkdir_p File.dirname(@config_path)
        file = File.open(@config_path, 'w')
        begin
          file.puts <<EOF
# Default user login
default_rhlogin='#{@username}'

# Server API
libra_server = '#{@libra_server}'
EOF

        ensure
          file.close
        end
        say "\n"
        say "Created local config file: " + @config_path
        say "express.conf contains user configuration and can be transferred across clients.\n\n"
        true
      end

      # Read in @config_path now that it exists (was skipped before because it did
      # not exist
      RHC::Config.set_local_config(@config_path)
    end

    def config_ssh_key_stage
      @ssh_priv_key_file_path = "#{RHC::Config.home_dir}/.ssh/id_rsa"
      @ssh_pub_key_file_path = "#{RHC::Config.home_dir}/.ssh/id_rsa.pub"
      unless File.exists? @ssh_priv_key_file_path
        say "No SSH Key has been found.  We're generating one for you."
        @ssh_pub_key_file_path = generate_ssh_key_ruby()
        say "    Created: #{@ssh_pub_key_file_path}\n\n"
      end
      true
    end

    def ssh_key_uploaded?
      @ssh_keys = RHC::get_ssh_keys(@libra_server, @username, @password, RHC::Config.default_proxy)
      additional_ssh_keys = @ssh_keys['keys']

      localkey = SSHKey.new File.read(@ssh_priv_key_file_path)
      local_fingerprint = localkey.md5_fingerprint

      return true if @ssh_keys['fingerprint'] == local_fingerprint
      additional_ssh_keys.each do |name, keyval|
        return true if keyval['fingerprint'] == local_fingerprint
      end

      false
    end

    def upload_ssh_key
      additional_ssh_keys = @ssh_keys['keys']
      known_keys = []

      say '\nWe need to upload your public key to remote servers so it can be ' \
          'used.  First you need to name it.  For example "liliWork" or ' \
          '"laptop".  You can overwrite an existing key by naming it or ' \
          'pick a new name.\n\n'

      say 'Current Keys:'

      if @ssh_keys['fingerprint'].nil?
        say "    None"
      else
        known_keys << 'default'
        say "    default - #{@ssh_keys['fingerprint']}"
      end

      if additional_ssh_keys && additional_ssh_keys.kind_of?(Hash)
        additional_ssh_keys.each do |name, keyval|
          say "    #{name} - #{keyval['fingerprint']}"
          known_keys.push(name)
        end
      end

      say "\n"
      if @ssh_keys['fingerprint'].nil?
        key_name = "default"
        say "You don't have any keys setup yet so uploading as your default key"
      else
        key = SSHKey.new File.read(@ssh_priv_key_file_path)
        fingerprint = key.md5_fingerprint
        pubkey_default_name = fingerprint[0, 12].gsub(/[^0-9a-zA-Z]/,'')
        key_name =  ask("Provide a name for this key: ") do |q|
          q.default = pubkey_default_name
          q.validate = lambda { |p| RHC::check_key(p) }
        end
      end

      if known_keys.include?(key_name)
        say "\nKey already exists!  Updating key #{key_name} .. "
        add_or_update_key('update', key_name, @ssh_pub_key_file_path, @username, @password)
      else
        say "\nSending new key #{key_name} .. "
        add_or_update_key('add', key_name, @ssh_pub_key_file_path, @username, @password)
      end
      true
    end

    def upload_ssh_key_stage
      unless ssh_key_uploaded?
        upload = agree "Your public ssh key needs to be uploaded to the server.  Would you like us to upload it for you? (yes/no) "

        if upload
          upload_ssh_key
        else
          say "\n"
          say "You can upload your ssh key at a later time using the 'rhc sshkey' command\n\n"
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
      if Rhc::Platform.windows?
        windows_install
      else
        # we use command line tools for dbus since the dbus gem is not cross
        # platform and compiles itself on the host system when installed
        say "We will now check to see if you have the necessary client tools installed.\n\n"
        if has_dbus_send?
          package_kit_install
        else
          generic_unix_install_check
        end
      end
      true
    end

    def finalize_stage
      say "Thank you for setting up your system.  You can rerun this at any " \
          "time by calling 'rhc setup'. We will now execute your original " \
          "command (rhc #{ARGV.join(" ")})"
    end

    def dbus_send_session_method(name, service, obj_path, iface, stringafied_params, wait_for_reply=true)
      method = "#{iface}.#{name}"
      print_reply = ""
      print_reply = "--print-reply" if wait_for_reply
      cmd = "dbus-send --session #{print_reply} --type=method_call \
            --dest=#{service} #{obj_path} #{method} #{stringafied_params}"
      output = `#{cmd}`

      throw output if output.start_with?('Error')

      # parse the output
      results = []
      output.each_with_index do |line, i|
        if i != 0 # discard first line
          param_type, value = line.chomp.split(" ", 2)

          case param_type
          when "boolean"
            results << (value == 'true')
          when "string"
            results << value
          else
            puts "unknown type #{param_type} - treating as string"
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

    def package_kit_install
      say "Checking for git ... "
      begin
        git_installed = package_kit_method('IsInstalled', 'Query', 'string:git string:')
        if git_installed
          say "found\n\n"
        else
          say "needs to be installed\n\n"
          install = agree "Would you like to launch the system installer? (yes/no) "
          if install
            package_kit_method('InstallPackageNames', 'Modify', 'uint32:0 array:string:"git" string:', false)
            say "You may safely continue while the installer is running or " \
                "you can wait until it has finished.  Press any key to continue:"

            get_character
            say "\n"
          end
        end
      rescue StandardError => e
        puts e.to_s
      end
    end

    def generic_unix_install_check
      say "Checking for git ... "
      if has_git?
        say "found\n\n"
      else
        say "needs to be installed\n\n"
        say "Automated installation of client tools is not supported for " \
            "your platform. You will need to manually install git for full " \
            "OpenShift functionality."
      end
    end

    def windows_install
      # Finding windows executables is hard since they can get installed
      # in non standard directories.  Punt on this for now and simply
      # print out urls and some instructions
      say <<EOF
In order to full interact with OpenShift you will need to install and configure a git client.

Documentation for installing the client tools can be found at https://openshift.redhat.com/app/getting_started#install_client_tools

We recommend these applications:

  * Git for Windows - a basic git command line and GUI client https://github.com/msysgit/msysgit/wiki/InstallMSysGit
  * TortoiseGit - git client that integrates into the file explorer http://code.google.com/p/tortoisegit/

EOF
    end

    def exe?(executable)
      ENV['PATH'].split(File::PATH_SEPARATOR).any? do |directory|
        File.executable?(File.join(directory, executable.to_s))
      end
    end

    def has_git?
      exe? 'git'
    end

    def has_dbus_send?
      bus = ENV['DBUS_SESSION_BUS_ADDRESS']
      exe? 'dbus-send' and !bus.nil? and bus.length > 0
    end
  end

  class RerunWizard < Wizard
    def initialize(config_path)
      super
    end

    def greeting_stage
      say "Starting Interactive Setup for OpenShift's command line interface\n\n"
      say "We'll help get you setup with just a couple of questions. " \
          "You can skip this in the future by copying your config's around:\n\n"

      say "    #{@config_path}"
      say "    #{RHC::Config.home_dir}/.ssh/\n\n"

      true
    end

    def create_config_stage
      if File.exists? @config_path
        backup = "#{@config_path}.bak"
        say "Configuration file #{@config_path} already exists, " \
            "backing up to #{backup}\n\n"
        File.cp(@config_path, backup)
      end
      super
      true
    end

    def finalize_stage
      say "Thank you for setting up your system.  You can rerun this at any time " \
          "by calling 'rhc setup'."
      true
    end
  end
end
