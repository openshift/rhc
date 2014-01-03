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
require 'httpclient'

module RHC
  module SSHHelpers

    class MultipleGearTask
      def initialize(command, over, opts={})
        requires_ssh_multi!

        @command = command
        @over = over
        @opts = opts
      end

      def run(&block)
        out = nil

        Net::SSH::Multi.start(
          :concurrent_connections => @opts[:limit],
          :on_error => lambda{ |server| $stderr.puts RHC::Helpers.color("Unable to connect to gear #{server}", :red) }
        ) do |session|

          @over.each do |item|
            case item
            when RHC::Rest::GearGroup
              item.gears.each do |gear|
                session.use ssh_host_for(gear), :properties => {:gear => gear, :group => item}
              end
            #when RHC::Rest::Gear
            #  session.use ssh_host_for(item), :properties => {:gear => item}
            #end
            else
              raise "Cannot establish an SSH session to this type"
            end
          end
          session.exec @command, &(
            case
            when @opts[:raw]
              lambda { |ch, dest, data|
                (dest == :stdout ? $stdout : $stderr).puts data
              }
            when @opts[:as] == :table
              out = []
              lambda { |ch, dest, data|
                label = label_for(ch)
                data.chomp.each_line do |line|
                  row = out.find{ |row| row[0] == label } || (out << [label, []])[-1]
                  row[1] << line
                end
              }
            when @opts[:as] == :gear
              lambda { |ch, dest, data| (ch.connection.properties[:gear]['data'] ||= "") << data }
            else
              width = 0
              lambda { |ch, dest, data|
                label = label_for(ch)
                io = dest == :stdout ? $stdout : $stderr
                data.chomp!

                if data.each_line.to_a.count < 2
                  io.puts "[#{label}] #{data}"
                elsif @opts[:always_prefix]
                  data.each_line do |line|
                    io.puts "[#{label}] #{line}"
                  end
                else
                  io.puts "=== #{label}"
                  io.puts data
                end
              }
            end)
          session.loop
        end

        if block_given? && !@opts[:raw]
          case
          when @opts[:as] == :gear
            out = []
            @over.each do |item|
              case item
              when RHC::Rest::GearGroup then item.gears.each{ |gear| out << yield(gear, gear['data'], item) }
              #when RHC::Rest::Gear      then out << yield(gear, gear['data'], nil)
              end
            end
          end
        end

        out
      end
      protected
        def ssh_host_for(gear)
          RHC::Helpers.ssh_string(gear['ssh_url']) or raise NoPerGearOperations
        end

        def label_for(channel)
          channel.properties[:label] ||=
            begin
              group = channel.connection.properties[:group]
              "#{key_for(channel)} #{group.cartridges.map{ |c| c['name'] }.join('+')}"
            end
        end

        def key_for(channel)
          channel.connection.properties[:gear]['id']
        end

        def requires_ssh_multi!
          begin
            require 'net/ssh/multi'
          rescue LoadError
            raise RHC::OperationNotSupportedException, "You must install Net::SSH::Multi to use the --gears option.  Most systems: 'gem install net-ssh-multi'"
          end
        end
    end

    def run_on_gears(command, gears, opts={}, &block)
      debug "Executing #{command} on each of #{gears.inspect}"
      MultipleGearTask.new(command, gears, {:limit => options.limit, :always_prefix => options.always_prefix, :raw => options.raw}.merge(opts)).run(&block)
    end

    def table_from_gears(command, groups, opts={}, &block)
      cells = run_on_gears(command, groups, {:as => :table}.merge(opts), &block)
      cells.each{ |r| r.concat(r.pop.first.split(opts[:split_cells_on])) } if !block_given? && opts[:split_cells_on]
      say table cells, opts unless options.raw
    end

    def ssh_command_for_op(operation)
      #case operation
      raise RHC::OperationNotSupportedException, "The operation #{operation} is not supported."
      #end
    end

    # Public: Run ssh command on remote host
    #
    # host - The String of the remote hostname to ssh to.
    # username - The String username of the remote user to ssh as.
    # command - The String command to run on the remote host.
    # compression - Use compression in ssh, set to false if sending files.
    # request_pty - Request for pty, set to false when pipe a file.
    # block - Will yield this block and send the channel if provided.
    #
    # Examples
    #
    #  ssh_ruby('myapp-t.rhcloud.com',
    #            '109745632b514e9590aa802ec015b074',
    #            'rhcsh tail -f $OPENSHIFT_LOG_DIR/*"')
    #  # => true
    #
    # Returns true on success
    def ssh_ruby(host, username, command, compression=false, request_pty=false, &block)
      debug "Opening Net::SSH connection to #{host}, #{username}, #{command}"
      exit_status = 0
      Net::SSH.start(host, username, :compression => compression) do |session|
        #:nocov:
        channel = session.open_channel do |channel|
          if request_pty
            channel.request_pty do |ch, success|
              say "pty could not be obtained" unless success
            end
          end
          channel.exec(command) do |ch, success|
            channel.on_data do |ch, data|
              print data
            end
            channel.on_extended_data do |ch, type, data|
              print data
            end
            channel.on_close do |ch|
              debug "Terminating ... "
            end
            channel.on_request("exit-status") do |ch, data|
              exit_status = data.read_long
            end
            yield channel if block_given?
            channel.eof!
          end
        end
        session.loop
        #:nocov:
      end
      raise RHC::SSHCommandFailed.new(exit_status) if exit_status != 0
    rescue Errno::ECONNREFUSED => e
      debug_error e
      raise RHC::SSHConnectionRefused.new(host, username)
    rescue Net::SSH::AuthenticationFailed => e
      debug_error e
      raise RHC::SSHAuthenticationFailed.new(host, username)
    rescue SocketError => e
      debug_error e
      raise RHC::ConnectionFailed, "The connection to #{host} failed: #{e.message}"
    end


    # Public: Run ssh command on remote host and pipe the specified
    # file contents to the command input
    #
    # host - The String of the remote hostname to ssh to.
    # username - The String username of the remote user to ssh as.
    # command - The String command to run on the remote host.
    # filename - The String path to file to send.
    #
    def ssh_send_file_ruby(host, username, command, filename)
      filename = File.expand_path(filename)
      ssh_ruby(host, username, command) do |channel|
        File.open(filename, 'rb') do |file|
          file.chunk(1024) do |chunk|
            channel.send_data chunk
          end
        end
      end
    end

    # Public: Run ssh command on remote host and pipe the specified
    # url contents to the command input
    #
    # host - The String of the remote hostname to ssh to.
    # username - The String username of the remote user to ssh as.
    # command - The String command to run on the remote host.
    # content_url - The url with the content to pipe to command.
    #
    def ssh_send_url_ruby(host, username, command, content_url)
      content_url = URI.parse(URI.encode(content_url.to_s))
      ssh_ruby(host, username, command) do |channel|
        HTTPClient.new.get_content(content_url) do |chunk|
          channel.send_data chunk
        end
      end
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
      nil
    rescue OpenSSL::PKey::PKeyError, Net::SSH::Exception => e
      error e.message
      nil
    rescue => e
      debug e.message
      nil
    end

    def fingerprint_for_default_key
      fingerprint_for_local_key(RHC::Config.ssh_pub_key_file_path)
    end

    # for an SSH public key specified by 'key', return a triple
    # [type, content, comment]
    # which is basically the space-separated list of the SSH public key content
    def ssh_key_triple_for(key)
      begin
        IO.read(key).chomp.split
      rescue Errno::ENOENT => e
        raise ::RHC::KeyFileNotExistentException.new("File '#{key}' does not exist.")
      rescue Errno::EACCES => e
        raise ::RHC::KeyFileAccessDeniedException.new("Access denied to '#{key}'.")
      end
    end

    def ssh_key_triple_for_default_key
      ssh_key_triple_for(RHC::Config.ssh_pub_key_file_path)
    end

    # check the version of SSH that is installed
    def ssh_version
      @ssh_version ||= `ssh -V 2>&1`.strip
    end

    # return whether or not SSH is installed
    def has_ssh?
      @has_ssh ||= begin
        @ssh_version = nil
        ssh_version
        $?.success?
      rescue
        false
      end
    end

    # return supplied ssh executable, if valid (executable, searches $PATH).
    # if none was supplied, return installed ssh, if any.
    def check_ssh_executable!(path)
      if not path
        raise RHC::InvalidSSHExecutableException.new("No system SSH available. Please use the --ssh option to specify the path to your SSH executable, or install SSH.") unless has_ssh?
        'ssh'
      else
        bin_path = path.split(' ').first
        raise RHC::InvalidSSHExecutableException.new("SSH executable '#{bin_path}' does not exist.") unless File.exist?(bin_path) or exe?(bin_path)
        raise RHC::InvalidSSHExecutableException.new("SSH executable '#{bin_path}' is not executable.") unless File.executable?(bin_path) or exe?(bin_path)
        path
      end
    end

    private

    def ssh_add
      if exe?('ssh-add')
        #:nocov:
        `ssh-add 2>&1`
        #:nocov:
      end
    end
  end
end
