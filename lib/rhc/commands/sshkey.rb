#! /usr/bin/env ruby

require 'rhc/commands/base'

module RHC::Commands
  class SshKey < Base
    include RHC::SSHKeyHelpers
    
    summary 'Manage multiple keys for the registered rhcloud user.'
    syntax '<action>'
    default_action :list
    
    summary 'Display all the SSH keys for the user account'
    syntax ''
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    def list
      ssh_keys = rest_client.sshkeys
      results do
        result = ''

        ssh_keys.each do |key|
          result += format(key, erb)
        end
        
        say result
      end
      
      0
    end
    
    summary 'List the SSH key with the given name'
    syntax '<name>'
    argument :name, 'SSH key to display', []
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    def show(name)
      key = rest_client.find_key(name)
      say format(key, erb)
      
      0
    end

    summary 'Add SSH key to the user account'
    syntax '<name> <SSH Key file>'
    argument :name, 'Name for this key', []
    argument :key, 'SSH public key filepath', []
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    def add(name, key)
      begin
        file = File.open(key)
      rescue Errno::ENOENT => e
        raise ::RHC::KeyFileNotExistentException.new("File '#{key}' does not exist.")
      rescue Errno::EACCES => e
        raise ::RHC::KeyFileAccessDeniedException.new("Access denied to '#{key}'.")
      end
      type, content, comment = file.gets.chomp.split
      rest_client.add_key(name, content, type)
      results { say "SSH key #{key} has been added as '#{name}'" }
      
      0
    end

    summary 'Deprecated. "remove" and "add" instead.'
    syntax ''
    def update
      warn 'Update command is deprecated. Please delete and re-add the key with the same name.'
      
      1
    end

    summary 'Remove SSH key from the user account'
    syntax '<name>'
    alias_action :delete
    argument :name, 'SSH key to remove', []
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    def remove(name)
      rest_client.delete_key(name)
      results { say "SSH key '#{name}' has been removed" }
      
      0
    end
    
    private
    # shared ERB template for formatting SSH Key
    def erb
      return @erb if @erb # cache
      @erb = ERB.new <<-FORMAT
       Name: <%= key.name %>
       Type: <%= key.type %>
Fingerprint: <%= key.fingerprint %>

      FORMAT
    end
    
  end
end