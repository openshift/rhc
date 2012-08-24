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

    private

    def ssh_add
      #:nocov:
      `ssh-add 2&>1`
      #:nocov:
    end
  end
end
