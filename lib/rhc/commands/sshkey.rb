require 'rhc/commands/base'

module RHC::Commands
  class Sshkey < Base
    include RHC::SSHHelpers

    summary 'Manage multiple keys for the registered rhcloud user.'
    syntax '<action>'
    default_action :list

    summary 'Display all the SSH keys for the user account'
    syntax ''
    def list
      keys = rest_client.sshkeys

      results do
        result = keys.inject('') do |r, key|
          r += format(key, erb)
        end
        say result
      end

      0
    end

    summary 'List the SSH key with the given name'
    syntax '<name>'
    argument :name, 'SSH key to display', []
    def show(name)
      key = rest_client.find_key(name)
      say format(key, erb)

      0
    end

    summary 'Add SSH key to the user account'
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

    summary 'Remove SSH key from the user account'
    syntax '<name>'
    alias_action :delete
    argument :name, 'SSH key to remove', []
    def remove(name)
      rest_client.delete_key(name)
      results { say "SSH key '#{name}' has been removed" }

      0
    end

    private
    # shared ERB template for formatting SSH Key
    def erb
      return @erb if @erb # cache
      @erb = ::RHC::Helpers.ssh_key_display_format
    end
  end
end
