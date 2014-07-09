require 'rhc/commands/base'
require 'resolv'
require 'rhc/git_helpers'
require 'rhc/cartridge_helpers'

module RHC::Commands
  class Ssh < Base
    suppress_wizard

    summary "SSH into the specified application"
    description <<-DESC
      Connect to your application using SSH.  This will connect to your primary gear
      (the one with your Git repository and web cartridge) by default.  To SSH to
      other gears run 'rhc show-app --gears' to get a list of their SSH hosts.

      You may run a specific SSH command by passing one or more arguments, or use a
      different SSH executable or pass options to SSH with the '--ssh' option.
      DESC
    syntax "[--ssh path_to_ssh_executable] [--gears] [<app> --] <command>"
    takes_application :argument => true
    argument :command, "Command to run in the application's SSH session", ['--command COMMAND'], :type => :list, :optional => true
    option ["--ssh PATH"], "Path to your SSH executable or additional options"
    option ["--gears"], "Execute this command on all gears in the app.  Requires a command."
    option ["--limit INTEGER"], "Limit the number of simultaneous SSH connections opened with --gears (default: 5).", :type => Integer, :default => 5
    option ["--raw"], "Output only the data returned by each host, no hostname prefix."
    alias_action 'app ssh', :root_command => true
    def run(_, command)
      raise ArgumentError, "--gears requires a command" if options.gears && command.blank?
      raise ArgumentError, "--limit must be an integer greater than zero" if options.limit && options.limit < 1

      ssh = check_ssh_executable! options.ssh

      if options.gears
        run_on_gears(command.join(' '), find_app(:with_gear_groups => true))
        0
      else
        rest_app = find_app
        $stderr.puts "Connecting to #{rest_app.ssh_string.to_s} ..." unless command.present?

        debug "Using user specified SSH: #{options.ssh}" if options.ssh

        command_line = [ ssh.split, ('-vvv' if debug?), rest_app.ssh_string.to_s, command ].flatten.compact

        debug "Invoking Kernel.exec with #{command_line.inspect}"
        Kernel.send(:exec, *command_line)
      end
    end

    protected
      include RHC::SSHHelpers
  end
end
