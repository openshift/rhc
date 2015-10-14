require 'rhc/commands/base'
require 'rhc/config'
require 'rhc/ssh_helpers'
require 'open3'

module RHC::Commands
  class Tail < Base
    include RHC::SSHHelpers

    summary "Tail the logs of an application"
    syntax "<application>"
    takes_application :argument => true
    option ["-o", "--opts options"], "Options to pass to the server-side (linux based) tail command (applicable to tail command only) (-f is implicit.  See the linux tail man page full list of options.) (Ex: --opts '-n 100')"
    option ["-f", "--files files"], "File glob relative to app (default <application_name>/logs/*) (optional)"
    option ["-g", "--gear ID"], "Tail only a specific gear"
    #option ["-c", "--cartridge name"], "Tail only a specific cartridge"
    alias_action :"app tail", :root_command => true, :deprecated => true
    def run(app_name)
      rest_app = find_app(:include => :cartridges)
      ssh_url = options.gear ? rest_app.gear_ssh_url(options.gear) : rest_app.ssh_url

      tail('*', URI(ssh_url), options)

      0
    end

    private
      #Application log file tailing
      def tail(cartridge_name, ssh_url, options)
        debug "Tail in progress for cartridge #{cartridge_name}"

        ssh = check_ssh_executable! options.ssh

        debug "Using user specified SSH: #{options.ssh}" if options.ssh

        host = ssh_url.host
        uuid = ssh_url.user

        file_glob = options.files ? options.files : "#{cartridge_name}/log*/*"
        remote_cmd = "tail#{options.opts ? ' --opts ' + Base64::encode64(options.opts).chomp : ''} #{file_glob}"
        #Use ssh -t to tail the logs
        ssh_cmd = "#{ssh} -t #{uuid}@#{host} '#{remote_cmd}'"

        begin
          if !options.ssh
            # Only use Net::SSH if no ssh executable is specified
            debug "Running with ruby's ssh implementation: #{ssh_cmd}"
            ssh_ruby(host, uuid, remote_cmd, false, true)
          else
            ssh_stderr = " 2>/dev/null"
            ssh_cmd << ssh_stderr unless debug?
            debug "Running #{ssh_cmd}"
            Open3.popen3(ssh_cmd) do |stdin, stdout, stderr, thread|
              while line=stdout.gets do
                print line
              end
            end
          end
        rescue
          warn "You can tail this application directly with:\n#{ssh_cmd}"
          raise
        end
      end
  end
end
