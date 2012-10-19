require 'rhc/commands/base'
module RHC::Commands
  class Snapshot < Base
    summary "Pull down application snapshot for a user."
    syntax "<action>"
    alias_action :"app snapshot", :root_command => true
    default_action :help

    summary "Pull down application snapshot for the specified application."
    syntax "<application>"
    option ["-n", "--namespace namespace"], "Namespace of the application you are saving a snapshot", :context => :namespace_context, :required => true
    option ["-f", "--filepath filepath"], "Local path to save tarball (default: ./$APPNAME.tar.gz)"
    argument :app, "Application you are saving a snapshot (required)", ["-a", "--app app"]
    alias_action :"app snapshot save", :root_command => true, :deprecated => true
    def save(app)
      ssh_uri = URI.parse(rest_client.find_domain(options.namespace).find_application(app).ssh_url)
      filename = options.filepath ? options.filepath : "#{app}.tar.gz"

      ssh_cmd = "ssh #{ssh_uri.user}@#{ssh_uri.host} 'snapshot' > #{filename}"
      debug ssh_cmd

      say "Pulling down a snapshot to #{filename}..."

      begin

        if ! RHC::Helpers.windows?
          output = Kernel.send(:`, ssh_cmd)
          if $?.exitstatus != 0
            debug output
            raise RHC::SnapshotSaveException.new "Error in trying to save snapshot. You can try to save manually by running:\n#{ssh_cmd}"
          end
        else
          Net::SSH.start(ssh_uri.host, ssh_uri.user) do |ssh|
            File.open(filename, 'wb') do |file|
              ssh.exec! "snapshot" do |channel, stream, data|
                if stream == :stdout
                  file.write(data)
                else
                  debug data
                end
              end
            end
          end
        end
      rescue Timeout::Error, Errno::EADDRNOTAVAIL, Errno::EADDRINUSE, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::SSH::AuthenticationFailed => e
        debug e.backtrace
        raise RHC::SnapshotSaveException.new "Error in trying to save snapshot. You can try to save manually by running:\n#{ssh_cmd}"
      end
      results { say "Success" }
      0
    end

    summary "Restores a previously saved snapshot."
    syntax "<application>"
    option ["-n", "--namespace namespace"], "Namespace of the application you are saving a snapshot", :context => :namespace_context, :required => true
    option ["-f", "--filepath filepath"], "Local path to save tarball (default: ./$APPNAME.tar.gz)"
    argument :app, "Application you are saving a snapshot (required)", ["-a", "--app app"]
    alias_action :"app snapshot restore", :root_command => true, :deprecated => true
    def restore(app)

      filename = options.filepath ? options.filepath : "#{app}.tar.gz"

      if File.exists? filename

        include_git = RHC::Helpers.windows? ? false : RHC::TarGz.contains(filename, './*/git')

        ssh_uri = URI.parse(rest_client.find_domain(options.namespace).find_application(app).ssh_url)

        ssh_cmd = "cat #{filename} | ssh #{ssh_uri.user}@#{ssh_uri.host} 'restore#{include_git ? ' INCLUDE_GIT' : ''}'"

        say "Restoring from snapshot #{filename}..."
        debug ssh_cmd

        begin
          if ! RHC::Helpers.windows?
            output = Kernel.` ssh_cmd
            if $?.exitstatus != 0
              debug output
              raise RHC::SnapshotRestoreException.new "Error in trying to restore snapshot. You can try to restore manually by running:\n#{ssh_cmd}"
            end
          else
            ssh = Net::SSH.start(ssh_uri.host, ssh_uri.user)
            ssh.open_channel do |channel|
              channel.exec("restore#{include_git ? ' INCLUDE_GIT' : ''}") do |ch, success|
                channel.on_data do |ch, data|
                  say data
                end
                channel.on_extended_data do |ch, type, data|
                  say data
                end
                channel.on_close do |ch|
                  say "Terminating..."
                end
                File.open(filename, 'rb') do |file|
                  file.chunk(1024) do |chunk|
                    channel.send_data chunk
                  end
                end
                channel.eof!
              end
            end
            ssh.loop
          end
        rescue Timeout::Error, Errno::EADDRNOTAVAIL, Errno::EADDRINUSE, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::SSH::AuthenticationFailed => e
          debug e.backtrace
          raise RHC::SnapshotRestoreException.new "Error in trying to restore snapshot. You can try to restore manually by running:\n#{ssh_cmd}"
        end

      else
        raise RHC::SnapshotRestoreException.new "Archive not found: #{filename}"
      end
      results { say "Success" }
      0
    end

  end
end
