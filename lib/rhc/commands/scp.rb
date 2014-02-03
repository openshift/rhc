require 'rhc/commands/base'
require 'rhc/scp_helpers'


module RHC::Commands
  class Scp < Base
    suppress_wizard

    summary "SCP a file to or from your application"
    description <<-DESC
      Transfer files to and from your applications using SCP.  This will transfer
      files to and from your primary gear (the one with the Git repository and web
      cartridge) by default.

      Examples:
        Uploading a file from your workding directory to your app-root/data directory
          rhc scp myapp upload somefile.txt app-root/data

        Downloading a file from your app-root/data directory to your working directory
          rhc scp myapp download ./ app-root/data/somebigarchive.tar.gz
    DESC
    syntax "[<app> --] <action> <local_path> <remote_path>"
    takes_application :argument => true
    argument :action, "Transfer direction: upload|download", ["-t", "--transfer_direction upload|download"], :optional => false
    argument :local_path, "Local filesystem path", ["-l", "--local_path file_path"], :optional => false
    argument :remote_path, "Remote filesystem path", ["-r", "--remote_path file_path"], :optional => false
    alias_action 'app scp', :root_command => true
    def run(_, action, local_path, remote_path)
      rest_app = find_app
      ssh_opts = rest_app.ssh_url.gsub("ssh://","").split("@")

      raise RHC::ArgumentNotValid.new("'#{action}' is not a valid argument for this command.  Please use upload or download.") unless action == 'download' || action == 'upload'
      raise RHC::FileOrPathNotFound.new("Local file, file_path, or directory could not be found.") unless File.exist?(local_path)
      
      begin
          start_time = Time.now
          Net::SCP.send("#{action}!".to_sym, ssh_opts[1], ssh_opts[0], (action == 'upload' ? local_path : remote_path), (action == 'upload' ? remote_path : local_path)) do |ch, name, sent, total|
            #:nocov:
            $stderr.print "\r #{action}ing #{name}: #{((sent.to_f/total.to_f)*100).to_i}% complete. #{sent}/#{total} bytes transferred " + (sent == total ? "in #{Time.now - start_time} seconds \n" : "")
            #:nocov:
          end
      rescue Errno::ECONNREFUSED
        raise RHC::SSHConnectionRefused.new(ssh_opts[0], ssh_opts[1])
      rescue SocketError => e
        raise RHC::ConnectionFailed, "The connection to #{ssh_opts[1]} failed: #{e.message}"
      rescue Net::SCP::Error => e
        raise RHC::RemoteFileOrPathNotFound.new("Remote file, file_path, or directory could not be found.")
      end
    end

    protected
    include RHC::SCPHelpers
  end
end
