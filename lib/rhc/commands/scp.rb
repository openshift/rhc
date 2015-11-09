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
        Uploading a file from your working directory to your app-root/data directory
          rhc scp myapp upload somefile.txt app-root/data

        Downloading a file from your app-root/data directory to your working directory
          rhc scp myapp download ./ app-root/data/somebigarchive.tar.gz
    DESC
    syntax "[<app> --] <action> <local_path> <remote_path>"
    takes_application :argument => true
    argument :action, "Transfer direction: upload|download", ["-t", "--transfer-direction upload|download"], :optional => false
    argument :local_path, "Local filesystem path", ["-f", "--local-path file_path"], :optional => false
    argument :remote_path, "Remote filesystem path", ["-r", "--remote-path file_path"], :optional => false
    alias_action 'app scp', :root_command => true
    def run(_, action, local_path, remote_path)
      rest_app = find_app
      ssh_opts = rest_app.ssh_url.gsub("ssh://","").split("@")

      raise RHC::ArgumentNotValid.new("'#{action}' is not a valid argument for this command.  Please use upload or download.") unless action == 'download' || action == 'upload'
      raise RHC::FileOrPathNotFound.new("Local file, file_path, or directory could not be found.") unless File.exist?(local_path)

      if options.ssh
        warn "User specified a ssh executable"
        if windows?
          warn("On Windows, file transfers to/from a gear can be completed with many different third-party tools such as FileZilla or WinSCP.\n" \
            "Alternatively, omit the --ssh flag and the 'ssh' directive in configuration to utilize the rhc tool's internal scp implementation.")
        else
          destination = "'#{ssh_opts[0]}@#{ssh_opts[1]}:$HOME/#{remote_path}'"
          if action == "upload"
            scp_cmd = "scp -S #{options.ssh} #{local_path} #{destination}"
          else
            scp_cmd = "scp -S #{options.ssh} #{destination} #{local_path}"
          end
          warn("'scp #{action}' can usually be used outside of rhc with the command:\n  #{scp_cmd}")
        end
        raise RHC::ArgumentNotValid.new("A SSH executable is specified and cannot be used with this command.")
      end

      begin
          start_time = Time.now
          last_sent = nil
          Net::SCP.send("#{action}!".to_sym, ssh_opts[1], ssh_opts[0], (action == 'upload' ? local_path : remote_path), (action == 'upload' ? remote_path : local_path)) do |ch, name, sent, total|
            #:nocov:
            if sent != last_sent
              last_sent = sent
              complete = total == 0 ? 100 : ((sent.to_f/total.to_f)*100).to_i
              $stderr.print "\r #{action}ing #{name}: #{complete}% complete. #{sent}/#{total} bytes transferred " + (sent == total ? "in #{Time.now - start_time} seconds \n" : "")
            end
            #:nocov:
          end
      rescue Errno::ECONNREFUSED
        raise RHC::SSHConnectionRefused.new(ssh_opts[0], ssh_opts[1])
      rescue SocketError => e
        raise RHC::ConnectionFailed, "The connection to #{ssh_opts[1]} failed: #{e.message}"
      rescue Net::SSH::AuthenticationFailed => e
        debug_error e
        raise RHC::SSHAuthenticationFailed.new(ssh_opts[1], ssh_opts[0])
      rescue Net::SCP::Error => e
        debug_error e
        raise RHC::RemoteFileOrPathNotFound.new("An unknown error occurred: #{e.message}")
      end
    end

    protected
    include RHC::SCPHelpers
  end
end
