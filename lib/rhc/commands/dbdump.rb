require 'rhc/commands/base'
require 'rhc/ssh_helpers'


module RHC::Commands
  class Dbdump < Base
    include RHC::SSHHelpers
    summary "asdfas"
    syntax "<action>"
    description <<-DESC
      Database dumps allow you to export the current state of your application's database
      into an archive on your local system, and then to restore it later.

      The dbdump archive contains dumps of any attached databases.

      WARNING: Both 'save' and 'restore' will stop the application and then restart
      after the operation completes.
      DESC
    alias_action :"app dbdump", :root_command => true
    default_action :help
    syntax "<application> [--filepath FILE] [--ssh path_to_ssh_executable]"
    takes_application :argument => true
    option ["-f", "--filepath FILE"], "Local path to save tarball (default: ./$APPNAME.tar.gz)"
    def save(app)
      ssh = check_ssh_executable! options.ssh
      rest_app = find_app
      ssh_uri = URI.parse(rest_app.ssh_url)
      filename = options.filepath ? options.filepath : "#{rest_app.name}.tar.gz"

      dbdump_cmd = 'gear dbdump'
      ssh_cmd = "#{ssh} #{ssh_uri.user}@#{ssh_uri.host} '#{dbdump_cmd}' > #{filename}"
      debug ssh_cmd

      say "Pulling down a dbdump to #{filename}..."
      begin
        if !RHC::Helpers.windows?
          status, output = exec(ssh_cmd)
          if status != 0
            debug output
            raise RHC::SnapshotSaveException.new "Error in trying to save dbdump. You can try to save manually by running:\n#{ssh_cmd}"
          end
        else
          Net::SSH.start(ssh_uri.host, ssh_uri.user) do |ssh|
            File.open(filename, 'wb') do |file|
              ssh.exec! "dbdump" do |channel, stream, data|
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
        raise RHC::SnapshotSaveException.new "Error in trying to save dbdump. You can try to save manually by running:\n#{ssh_cmd}"
      end
      results { say "Success" }
      0
    end
  end
end


