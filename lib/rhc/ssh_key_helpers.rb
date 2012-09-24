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
  module SSHKeyHelpers
    # Public: Generate an SSH key and store it in ~/.ssh/id_rsa
    #
    # type - The String type RSA or DSS.
    # bits - The Integer value for number of bits.
    # comment - The String comment for the key
    #
    # Examples
    #
    #  generate_ssh_key_ruby()
    #  # => /home/user/.ssh/id_rsa.pub
    #
    # Returns nil on failure or public key location as a String on success
    def generate_ssh_key_ruby(type="RSA", bits = 2048, comment = "OpenShift-Key")
      key = RHC::Vendor::SSHKey.generate(:type => type,
                                         :bits => bits,
                                         :comment => comment)
      ssh_dir = "#{RHC::Config.home_dir}/.ssh"
      if File.exists?("#{ssh_dir}/id_rsa")
        say "SSH key already exists: #{ssh_dir}/id_rsa.  Reusing..."
        return nil
      else
        unless File.exists?(ssh_dir)
          FileUtils.mkdir_p(ssh_dir)
          File.chmod(0700, ssh_dir)
        end
        File.open("#{ssh_dir}/id_rsa", 'w') {|f| f.write(key.private_key)}
        File.chmod(0600, "#{ssh_dir}/id_rsa")
        File.open("#{ssh_dir}/id_rsa.pub", 'w') {|f| f.write(key.ssh_public_key)}

        ssh_add if exe?('ssh-add')
      end
      "#{ssh_dir}/id_rsa.pub"
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
      # :nocov: no reason to cover this case
    rescue OpenSSL::PKey::PKeyError, Net::SSH::Exception => e
      error e.message
      return nil
      # :nocov:
    end
    
    def fingerprint_for_default_key
      fingerprint_for_local_key RHC::Config::ssh_pub_key_file_path
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
      ssh_key_triple_for RHC::Config::ssh_pub_key_file_path
    end

    private

    def ssh_add
      #:nocov:
      `ssh-add 2&>1`
      #:nocov:
    end
  end
end
