require 'rhc-common'

module RHC
  class Wizard
    @@stages = [:login, :create_config, :config_ssh_key, :upload_ssh_key]

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

    def login
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
    end

    def create_config
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
      end

      # Read in @config_path now that it exists (was skipped before because it did
      # not exist
      RHC::Config.set_local_config(@config_path)
    end

    def config_ssh_key
      unless File.exists? "#{RHC::Config.home_dir}/.ssh/id_rsa"
        puts ""
        puts "No SSH Key has been found.  We're generating one for you."
        ssh_pub_key_file_path = generate_ssh_key_ruby()
        puts "    Created: #{ssh_pub_key_file_path}"
        puts ""
      end
    end

    def upload_ssh_key
      # TODO: Name and upload new key

      puts <<EOF
Last step, we need to upload the newly generated public key to remote servers
so it can be used.  First you need to name it.  For example "liliWork" or
"laptop".  You can overwrite an existing key by naming it or pick a new
name.

Current Keys:
EOF
      ssh_keys = RHC::get_ssh_keys(@libra_server, @username, @password, RHC::Config.default_proxy)
      additional_ssh_keys = ssh_keys['keys']
      known_keys = ['default']
      puts "    default - #{ssh_keys['fingerprint']}" 
      if additional_ssh_keys && additional_ssh_keys.kind_of?(Hash)
        additional_ssh_keys.each do |name, keyval|
          puts "    #{name} - #{keyval['fingerprint']}"
          known_keys.push(name)
        end
      end

      puts "Name your new key: "
      while((key_name = RHC::check_key(gets.chomp)) == false)
        print "Try again.  Name your key: "
      end

      if known_keys.include?(key_name)
        puts ""
        puts "Key already exists!  Updating.."
        add_or_update_key('update', key_name, ssh_pub_key_file_path, @username, @password)
      else
        puts ""
        puts "Sending new key.."
        add_or_update_key('add', key_name, ssh_pub_key_file_path, @username, @password)
      end
    end

  end
end
