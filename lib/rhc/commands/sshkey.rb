require 'rhc/commands/base'

module RHC::Commands
  class Sshkey < Base
    include RHC::SSHHelpers

    summary 'Add and remove keys for Git and SSH'
    syntax '<action>'
    description <<-DESC
      OpenShift uses public keys to securely access your application source
      code and to control access to your application gears via SSH.  Your
      account may have one or more public SSH keys associated with it, and
      any computer with the private SSH key will be able to download code
      from Git or SSH to the application.

      Depending on your operating system, you may have to ensure that both
      Git and the local SSH installation have access to your keys.  Running
      the 'setup' command is any easy way to get your first key created and
      uploaded.
      DESC
    default_action :list

    summary 'Display all the SSH keys for your account'
    syntax ''
    def list
      keys = rest_client.sshkeys.each{ |key| paragraph{ display_key(key) } }

      success "You have #{keys.length} SSH keys associated with your account."

      0
    end

    summary 'Show the SSH key with the given name'
    syntax '<name>'
    argument :name, 'SSH key to display', []
    def show(name)
      key = rest_client.find_key(name)
      display_key(key)

      0
    end

    summary 'Add SSH key to your account'
    syntax '<name> <path to SSH key file>'
    argument :name, 'Name for this key', []
    argument :key, 'SSH public key filepath', []
    option ['--confirm'], 'Bypass key validation'
    def add(name, key)
      type, content, comment = ssh_key_triple_for(key)

      # validate the user input before sending it to the server
      begin
        Net::SSH::KeyFactory.load_data_public_key "#{type} #{content}"
      rescue NotImplementedError, OpenSSL::PKey::PKeyError, Net::SSH::Exception => e
        debug e.inspect
        if options.confirm
          warn 'The key you are uploading is not recognized.  You may not be able to authenticate to your application through Git or SSH.'
        else
          raise ::RHC::KeyDataInvalidException.new("File '#{key}' does not appear to be a recognizable key file (#{e}). You may specify the '--confirm' flag to add the key anyway.")
        end
      end

      rest_client.add_key(name, content, type)
      results { say "SSH key #{key} has been added as '#{name}'" }

      0
    end

    summary 'Remove SSH key from your account'
    syntax '<name>'
    alias_action :delete
    argument :name, 'Name of SSH key to remove'
    def remove(name)
      say "Removing the key '#{name} ... "
      rest_client.delete_key(name)

      success "removed"

      0
    end
  end
end
