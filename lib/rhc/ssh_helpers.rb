###
# ssh_key_helpers.rb - methods to help manipulate ssh keys
#
# Copyright 2012 Red Hat, Inc. and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
#  limitations under the License.

require 'net/ssh'
require 'rhc/vendor/sshkey'

module RHC
  module SSHHelpers
    # Public: Run ssh command on remote host
    #
    # host - The String of the remote hostname to ssh to.
    # username - The String username of the remote user to ssh as.
    # command - The String command to run on the remote host.
    #
    # Examples
    #
    #  ssh_ruby('myapp-t.rhcloud.com',
    #            '109745632b514e9590aa802ec015b074',
    #            'rhcsh tail -f $OPENSHIFT_LOG_DIR/*"')
    #  # => true
    #
    # Returns true on success
    def ssh_ruby(host, username, command)
      debug "Opening Net::SSH connection to #{host}, #{username}, #{command}"
      Net::SSH.start(host, username) do |session|
        #:nocov:
        session.open_channel do |channel|
          channel.request_pty do |ch, success|
            say "pty could not be obtained" unless success
          end

          channel.on_data do |ch, data|
            puts data
          end
          channel.exec command
        end
        session.loop
        #:nocov:
      end
    rescue Errno::ECONNREFUSED => e
      raise RHC::SSHConnectionRefused.new(host, username)
    rescue SocketError => e
      raise RHC::ConnectionFailed, "The connection to #{host} failed: #{e.message}"
    end

    # Public: Generate an SSH key and store it in ~/.ssh/id_rsa
    #
    # type - The String type RSA or DSS.
    # bits - The Integer value for number of bits.
    # comment - The String comment for the key
    #
    # Examples
    #
    #  generate_ssh_key_ruby
    #  # => /home/user/.ssh/id_rsa.pub
    #
    # Returns nil on failure or public key location as a String on success
    def generate_ssh_key_ruby(type="RSA", bits = 2048, comment = "OpenShift-Key")
      key = RHC::Vendor::SSHKey.generate(:type => type,
                                         :bits => bits,
                                         :comment => comment)
      ssh_dir = RHC::Config.ssh_dir
      priv_key = RHC::Config.ssh_priv_key_file_path
      pub_key = RHC::Config.ssh_pub_key_file_path

      if File.exists?(priv_key)
        say "SSH key already exists: #{priv_key}.  Reusing..."
        return nil
      else
        unless File.exists?(ssh_dir)
          FileUtils.mkdir_p(ssh_dir)
          File.chmod(0700, ssh_dir)
        end
        File.open(priv_key, 'w') {|f| f.write(key.private_key)}
        File.chmod(0600, priv_key)
        File.open(pub_key, 'w') {|f| f.write(key.ssh_public_key)}

        ssh_add
      end
      pub_key
    end

    def exe?(executable)
      ENV['PATH'].split(File::PATH_SEPARATOR).any? do |directory|
        File.executable?(File.join(directory, executable.to_s))
      end
    end

    # Public: Format SSH key's core attributes (name, type, fingerprint)
    # in a given ERB template
    # 
    # key - an object to be formatted
    # template - ERB template
    def format(key, template)
      template.result(binding)
    end


    # For Net::SSH versions (< 2.0.11) that does not have
    # Net::SSH::KeyFactory.load_public_key, we drop to shell to get
    # the key's fingerprint
    def ssh_keygen_fallback(path)
      fingerprint = `ssh-keygen -lf #{path} 2>&1`.split(' ')[1]

      if $?.exitstatus != 0
        error "Unable to compute SSH public key finger print for #{path}"
      end
      fingerprint
    end

    def fingerprint_for_local_key(key)
      Net::SSH::KeyFactory.load_public_key(key).fingerprint
    rescue NoMethodError, NotImplementedError => e
      ssh_keygen_fallback key
      return nil
    rescue OpenSSL::PKey::PKeyError, Net::SSH::Exception => e
      error e.message
      return nil
    end

    def fingerprint_for_default_key
      fingerprint_for_local_key RHC::Config.ssh_pub_key_file_path
    end

    # for an SSH public key specified by 'key', return a triple
    # [type, content, comment]
    # which is basically the space-separated list of the SSH public key content
    def ssh_key_triple_for(key)
      begin
        file = File.open key
      rescue Errno::ENOENT => e
        raise ::RHC::KeyFileNotExistentException.new("File '#{key}' does not exist.")
      rescue Errno::EACCES => e
        raise ::RHC::KeyFileAccessDeniedException.new("Access denied to '#{key}'.")
      end
      file.gets.chomp.split
    end
    
    def ssh_key_triple_for_default_key
      ssh_key_triple_for RHC::Config.ssh_pub_key_file_path
    end

    private

    def ssh_add
      if exe?('ssh-add')
        #:nocov:
        `ssh-add 2&>1`
        #:nocov:
      end
    end
  end
end
