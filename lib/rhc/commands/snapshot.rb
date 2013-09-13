require 'rhc/commands/base'

module RHC::Commands
  class Snapshot < Base
    summary "Save the current state of your application locally"
    syntax "<action>"
    description <<-DESC
      Snapshots allow you to export the current state of your OpenShift application
      into an archive on your local system, and then to restore it later.

      The snapshot archive contains the Git repository, dumps of any attached databases,
      and any other information that the cartridges decide to export.

      WARNING: Both 'save' and 'restore' will stop the application and then restart
      after the operation completes.
      DESC
    alias_action :"app snapshot", :root_command => true
    default_action :help

    summary "Save a snapshot of your app to disk"
    syntax "<application> [--filepath FILE] [--ssh path_to_ssh_executable]"
    option ["-n", "--namespace NAME"], "Namespace of the application you are saving a snapshot", :context => :namespace_context, :required => true
    option ["-f", "--filepath FILE"], "Local path to save tarball (default: ./$APPNAME.tar.gz)"
    option ["--ssh PATH"], "Full path to your SSH executable with additional options"
    argument :app, "Application you are saving a snapshot", ["-a", "--app NAME"]
    alias_action :"app snapshot save", :root_command => true, :deprecated => true
    def save(app)
      raise OptionParser::InvalidOption, "No system SSH available. Please use the --ssh option to specify the path to your SSH executable, or install SSH." unless options.ssh or has_ssh?
      raise OptionParser::InvalidOption, "SSH executable '#{options.ssh}' does not exist." if options.ssh and not File.exist?(options.ssh.split(' ').first)
      raise OptionParser::InvalidOption, "SSH executable '#{options.ssh}' is not executable." if options.ssh and not File.executable?(options.ssh.split(' ').first)
      rest_app = rest_client.find_application(options.namespace, app)
      ssh_uri = URI.parse(rest_app.ssh_url)
      filename = options.filepath ? options.filepath : "#{app}.tar.gz"

      ssh = options.ssh || 'ssh'
      ssh_cmd = "#{ssh} #{ssh_uri.user}@#{ssh_uri.host} 'snapshot' > #{filename}"
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

    summary "Restores a previously saved snapshot"
    syntax "<application> [--filepath FILE] [--ssh path_to_ssh_executable]"
    option ["-n", "--namespace NAME"], "Namespace of the application you are restoring a snapshot", :context => :namespace_context, :required => true
    option ["-f", "--filepath FILE"], "Local path to restore tarball"
    option ["--ssh PATH"], "Full path to your SSH executable with additional options"
    argument :app, "Application of which you are restoring a snapshot", ["-a", "--app NAME"]
    alias_action :"app snapshot restore", :root_command => true, :deprecated => true
    def restore(app)
      raise OptionParser::InvalidOption, "No system SSH available. Please use the --ssh option to specify the path to your SSH executable, or install SSH." unless options.ssh or has_ssh?
      raise OptionParser::InvalidOption, "SSH executable '#{options.ssh}' does not exist." if options.ssh and not File.exist?(options.ssh.split(' ').first)
      raise OptionParser::InvalidOption, "SSH executable '#{options.ssh}' is not executable." if options.ssh and not File.executable?(options.ssh.split(' ').first)

      filename = options.filepath ? options.filepath : "#{app}.tar.gz"

      if File.exists? filename

        include_git = RHC::Helpers.windows? ? true : RHC::TarGz.contains(filename, './*/git')
        rest_app = rest_client.find_application(options.namespace, app)
        ssh_uri = URI.parse(rest_app.ssh_url)

        ssh = options.ssh || 'ssh'
        ssh_cmd = "cat '#{filename}' | #{ssh} #{ssh_uri.user}@#{ssh_uri.host} 'restore#{include_git ? ' INCLUDE_GIT' : ''}'"

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

    protected
      include RHC::SSHHelpers
  end
end
