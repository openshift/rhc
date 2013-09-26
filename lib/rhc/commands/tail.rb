require 'rhc/commands/base'
require 'rhc/config'
require 'rhc/ssh_helpers'

module RHC::Commands
  class Tail < Base
    include RHC::SSHHelpers

    summary "Tail the logs of an application"
    syntax "<application>"
    argument :app, "Name of application you wish to view the logs of", ["-a", "--app NAME"]
    option ["-n", "--namespace NAME"], "Namespace of your application", :context => :namespace_context, :required => true
    option ["-o", "--opts options"], "Options to pass to the server-side (linux based) tail command (applicable to tail command only) (-f is implicit.  See the linux tail man page full list of options.) (Ex: --opts '-n 100')"
    option ["-f", "--files files"], "File glob relative to app (default */logs/*) (optional)"
    option ["-g", "--gear ID"], "Tail only a specific gear"
    option ["--primary-gear"], "Tail only the first gear"
    #option ["-c", "--cartridge name"], "Tail only a specific cartridge"
    alias_action :"app tail", :root_command => true, :deprecated => true
    def run(app_name)
      cmd = remote_tail_command(options)

      if options.gear or options.primary_gear
        rest_app = rest_client.find_application(options.namespace, app_name)
        host, user = ssh_string_parts(options.gear ? rest_app.gear_ssh_url(options.gear) : rest_app.ssh_url)
        ssh_cmd = "ssh -t #{user}@#{host} '#{cmd}'"
        begin
          debug ssh_cmd
          ssh_ruby(host, user, cmd)
        rescue
          warn "You can tail this application directly with:\n#{ssh_cmd}"
          raise
        end
      else
        groups = rest_client.find_application_gear_groups(options.namespace, app_name)
        run_on_gears(cmd, groups, :always_prefix => (true if options.always_prefix.nil?))
      end

      0
    end

    private
      def remote_tail_command(options, cartridge_name='*')
        file_glob = options.files ? options.files : "#{cartridge_name}/log*/*"
        "tail #{options.opts ? options.opts : ''} #{file_glob}"
      end

      #Application log file tailing
      def tail(cartridge_name, ssh_url, options)
        debug "Tail in progress for cartridge #{cartridge_name}"

        host = ssh_url.host
        uuid = ssh_url.user

        file_glob = options.files ? options.files : "#{cartridge_name}/log*/*"
        remote_cmd = "tail#{options.opts ? ' --opts ' + Base64::encode64(options.opts).chomp : ''} #{file_glob}"
        ssh_cmd = "ssh -t #{uuid}@#{host} '#{remote_cmd}'"
        begin
          #Use ssh -t to tail the logs
          debug ssh_cmd
          ssh_ruby(host, uuid, remote_cmd)
        rescue
          warn "You can tail this application directly with:\n#{ssh_cmd}"
          raise
        end
      end
  end
end
