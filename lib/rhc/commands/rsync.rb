require 'rhc/commands/base'
require 'resolv'
require 'rhc/git_helpers'
require 'rhc/cartridge_helpers'
require 'rhc/rsync_helpers'

module RHC::Commands
  class Rsync < Base
    suppress_wizard

    summary "Synchronize a file or directory with your application using rsync"
    description <<-DESC
      Synchronize files or directories with your applications using rsync.  This command will synchronize
      files and directories to and from your primary gear (the one with the Git repository and web
      cartridge) by default.

      Default options used are -avzr

      Examples:
        Synchronizing a file or directory from your local machine to your app-root/data directory
          rhc scp myapp upload somefile.txt app-root/data

      Synchronizing a file or directory from your app-root/data directory to your local machine
        rhc scp myapp download ./ app-root/data/somebigarchive.tar.gz

      You may run a specific rsync command by passing one or more arguments, or use a
      different rsync executable or pass options to rsync with the '--rsync' option.
      DESC
    syntax "[<app> --] <action> <local_path> <remote_path>"
    takes_application :argument => true
    option ["--rsync PATH"], "Path to your rsync executable or additional options"
    argument :action, "Transfer direction: upload|download", ["-t", "--transfer_direction upload|download"], :optional => false
    argument :local_path, "Local filesystem path", ["-l", "--local_path file_path"], :optional => false
    argument :remote_path, "Remote filesystem path", ["-r", "--remote_path file_path"], :optional => false
    alias_action 'app rsync', :root_command => true
    def run(_, action, local_path, remote_path)

      rsync = check_rsync_executable! options.rsync

      raise RHC::ArgumentNotValid.new("'#{action}' is not a valid argument for this command.  Please use upload or download.") unless action == 'download' || action == 'upload'
      raise RHC::FileOrPathNotFound.new("Local file, file_path, or directory could not be found.") unless File.exist?(local_path)

      rest_app = find_app

      debug "Using user specified rsync: #{options.rsync}" if options.rsync
      $stderr.puts "Synchronizing files with #{rest_app.ssh_string.to_s}"

      command_line = [ rsync.split, "-avzr", (action == "upload" ? local_path : rest_app.ssh_string.to_s+":"+remote_path) , (action == "upload" ? rest_app.ssh_string.to_s+":"+remote_path : local_path)].flatten.compact


      debug "Invoking Kernel.exec with #{command_line.inspect}"
      Kernel.send(:exec, *command_line)
    end

    protected
      include RHC::RsyncHelpers
  end
end
