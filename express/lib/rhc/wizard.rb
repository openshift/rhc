require 'rhc-common'

module RHC
  class Wizard
    @@stages = [:login_stage, :create_config_stage, :config_ssh_key_stage, :upload_ssh_key_stage]

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

    def login_stage
      puts <<EOF

Starting Interactive Setup.

It looks like you've not used OpenShift Express on this machine before.  We'll
help get you setup with just a couple of questions.  You can skip this in the
future by copying your config's around:

EOF
      puts "    #{@config_path}"
      puts "    #{RHC::Config.home_dir}/.ssh/"
      puts ""
      @username = ask("https://openshift.redhat.com/ username: ")
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
        puts ""
        puts "Created local config file: " + @config_path
        puts "express.conf contains user configuration and can be transferred across clients."
        puts ""
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
        puts ""
        puts "No SSH Key has been found.  We're generating one for you."
        @ssh_pub_key_file_path = generate_ssh_key_ruby()
        puts "    Created: #{@ssh_pub_key_file_path}"
        puts ""
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
      known_keys = ['default']

      puts <<EOF

Last step, we need to upload your public key to remote servers
so it can be used.  First you need to name it.  For example "liliWork" or
"laptop".  You can overwrite an existing key by naming it or pick a new
name.

Current Keys:
   default - #{@ssh_keys['fingerprint']}
EOF
      if additional_ssh_keys && additional_ssh_keys.kind_of?(Hash)
        additional_ssh_keys.each do |name, keyval|
          puts "   #{name} - #{keyval['fingerprint']}"
          known_keys.push(name)
        end
      end

      puts ""
      puts "Name your new key: "
      while((key_name = RHC::check_key($stdin.gets.chomp)) == false)
        print "Try again.  Name your key: "
      end

      if known_keys.include?(key_name)
        puts ""
        puts "Key already exists!  Updating.."
        add_or_update_key('update', key_name, @ssh_pub_key_file_path, @username, @password)
      else
        puts ""
        puts "Sending new key.."
        add_or_update_key('add', key_name, @ssh_pub_key_file_path, @username, @password)
      end
      true
    end

    def upload_ssh_key_stage
      unless ssh_key_uploaded?
        print "Your public ssh key needs to be uloaded to the server.  Would you like us to upload it for you? (yes/no) "
        while(!['y', 'n', 'yes', 'no'].include?(upload = $stdin.gets.chomp.downcase))
          print "Please enter yes or no.  Would you like to upload your public ssh key? "
        end

        if ['y', 'yes'].include? upload
          upload_ssh_key
        else
          puts ""
          puts "You can upload your ssh key at a later time using the 'rhc sshkey' command"
          puts ""
        end
      end
      true
    end
  end
end
