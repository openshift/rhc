require 'rhc/commands/base'
require 'rhc/config'
require 'rhc/ssh_helpers'

module RHC::Commands
  class Tail < Base
    include RHC::SSHHelpers

    summary "Tail the logs of an application"
    syntax "<application>"
    argument :app, "Name of application you wish to view the logs of", ["-a", "--app app"]
    option ["-n", "--namespace namespace"], "Namespace of your application", :context => :namespace_context, :required => true
    option ["-o", "--opts options"], "Options to pass to the server-side (linux based) tail command (applicable to tail command only) (-f is implicit.  See the linux tail man page full list of options.) (Ex: --opts '-n 100')"
    option ["-f", "--files files"], "File glob relative to app (default <application_name>/logs/*) (optional)"
    alias_action :"app tail", :root_command => true, :deprecated => true
    def run(app_name)
      domain = rest_client.find_domain(options.namespace)
      app = domain.find_application(app_name)
      cartridges = app.cartridges

      tail(cartridges.first.name, URI(app.ssh_url), options)

      0
    end

    private 
      #Application log file tailing
      def tail(cartridge_name, ssh_url, options)
        debug "Tail in progress for cartridge #{cartridge_name}"

        host = ssh_url.host
        uuid = ssh_url.user

        file_glob = options.files ? options.files : "#{cartridge_name}/logs/*"
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
