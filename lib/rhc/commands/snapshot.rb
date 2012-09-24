require 'rhc/commands/base'
module RHC::Commands
  class Snapshot < Base
    summary "Pull down application snapshot for a user."
    syntax "<action>"
    alias_action :"app snapshot", :root_command => true
    default_action :save

    summary "Pull down application snapshot for the specified application."
    syntax "<application>"
    option ["-n", "--namespace namespace"], "Namespace of the application you are port forwarding to", :context => :namespace_context, :required => true
    option ["-f", "--filepath filepath"], "Local path to save tarball (default: ./$APPNAME.tar.gz)"
    argument :app, "Application you are port forwarding to (required)", ["-a", "--app app"]
    alias_action :"app snapshot", :root_command => true
    def save(app)
      ssh_uri = URI.parse(rest_client.find_domain(options.namespace).find_application(app).ssh_url)
      filename = "#{app}.tar.gz" unless options.filepath

      ssh_cmd = "ssh #{ssh_uri.user}@#{ssh_uri.host} 'snapshot' > #{filename}"
      debug ssh_cmd

      say "Pulling down a snapshot to #{filename}..."

      begin

        if ! RHC::Helpers.windows?
          output = `#{ssh_cmd}`
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
    option ["-n", "--namespace namespace"], "Namespace of the application you are port forwarding to", :context => :namespace_context, :required => true
    option ["-f", "--filepath filepath"], "Local path to save tarball (default: ./$APPNAME.tar.gz)"
    argument :app, "Application you are port forwarding to (required)", ["-a", "--app app"]
    alias_action :"app snapshot", :root_command => true
    def restore(app)

      filename = "#{app}.tar.gz" unless options.filepath

      if File.exists? filename

        if ! RHC::Helpers.windows? and ! RHC::TarGz.contains filename, './*/' + app
          raise RHC::SnapshotRestoreException.new "Archive at #{filename} does not contain the target application: ./*/#{app}
          If you created this archive rather than exported with rhc snapshot save, be sure
          the directory structure inside the archive starts with ./<app_uuid>/
          i.e.: tar -czvf <app_name>.tar.gz ./<app_uuid>/"
        else

          include_git = RHC::Helpers.windows? ? false : RHC::TarGz.contains(filename, './*/git')

          ssh_uri = URI.parse(rest_client.find_domain(options.namespace).find_application(app).ssh_url)

          ssh_cmd = "cat #{filename} | ssh #{ssh_uri.user}@#{ssh_uri.host} 'restore#{include_git ? ' INCLUDE_GIT' : ''}'"

          say "Restoring from snapshot #{filename}..."
          debug ssh_cmd

          begin
            if ! RHC::Helpers.windows?
              output = `#{ssh_cmd}`
              if $?.exitstatus != 0
                debug output
                raise RHC::SnapshotRestoreException.new "Error in trying to restore snapshot. You can try to restore manually by running:\n#{ssh_cmd}"
                return 1
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
            raise RHC::SnapshotRestoreException.new "Error in trying to restore snapshot. You can try to save manually by running:\n#{ssh_cmd}"
          end

        end
      else
        raise RHC::SnapshotRestoreException.new "Archive not found: #{filename}"
      end
      results { say "Success" }
      0
    end

  end
end
