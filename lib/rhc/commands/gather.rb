require 'rhc/commands/base'
require 'rhc/config'
require 'rhc/ssh_helpers'

module RHC::Commands
  class Gather < Base
    include RHC::SSHHelpers

    summary "Gather useful information to assist with troubleshooting"
    syntax "<application>"
    argument :app, "Name of application you wish to view the logs of", ["-a", "--app NAME"]
    option ["-n", "--namespace NAME"], "Namespace of your application", :context => :namespace_context, :required => true

    def run(app_name)
      rest_app = rest_client.find_application(options.namespace, app_name, :include => :cartridges)
      ssh_url = options.gear ? rest_app.gear_ssh_url(options.gear) : rest_app.ssh_url
      ssh_uri = URI.parse(rest_app.ssh_url)

      paragraph do
        header "Gear Information"
        gear_info = gear_groups_for_app(app_name).map do |group|
          group.gears.map do |gear|
            [
              gear['id'],
              gear['state'] == 'started' ? gear['state'] : color(gear['state'], :yellow),
              group.cartridges.collect{ |c| c['name'] }.join(' '),
              group.gear_profile,
              ssh_string(gear['ssh_url'])
            ]
          end
        end.flatten(1)

      say table(gear_info, :header => ['ID', 'State', 'Cartridges', 'Size', 'SSH URL'])
      end

      paragraph do
        header "Quota"

        Net::SSH.start( ssh_uri.host, ssh_uri.user) do |ssh|
          output = ssh.exec!('quota -s')

          puts output
        end
      end

      paragraph do
        header "Logs:"
        tail('*', URI(ssh_url), options)
      end

    end

    private

    def gear_groups_for_app(app_name)
      rest_client.find_application_gear_groups(options.namespace, app_name)
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
