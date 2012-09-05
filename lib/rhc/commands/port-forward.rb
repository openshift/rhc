require 'rhc/commands/base'

module RHC::Commands
  class PortForward < Base

    summary "Forward remote ports to the workstation"
    option ["-n", "--namespace namespace"], "Namespace of the application you are port forwarding to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you are port forwarding to (required)", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    def run

      app = options.app
      namespace = options.namespace

      rest_domain = rest_client.find_domain namespace
      rest_app = rest_domain.find_application app

      if (rest_app.embedded && rest_app.embedded.keys.any?{ |k| k =~ /\Ahaproxy/ })
        raise RHC::ScaledApplicationsNotSupportedException.new "This utility does not currently support scaled applications. You will need to set up port forwarding manually."
      end

      say "Checking available ports..."

      ip_and_port_simple_regex = /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\:[0-9]{1,5}/

      app_uuid, ssh_host = rest_app.ssh_url[6..-1].split('@')

      say "Using #{app_uuid}@#{ssh_host}..." if options.debug

      hosts_and_ports = []
      hosts_and_ports_descriptions = []

      begin

        Net::SSH.start(ssh_host, app_uuid) do |ssh|

          ssh.exec! "rhc-list-ports" do |channel, stream, data|

            if stream == :stderr

              data.lines { |line|

                line = line.chomp

                if line.downcase =~ /permission denied/
                  raise RHC::PermissionDeniedException.new line
                end

                if line.index(ip_and_port_simple_regex)
                  hosts_and_ports_descriptions << line
                end
              }

            else

              data.lines { |line|

                line = line.chomp

                if not line.downcase =~ /scale/
                  if ip_and_port_simple_regex.match(line)
                    hosts_and_ports << line
                  end
                end
              }

            end

          end

          if hosts_and_ports.length == 0
            results { say "No available ports to forward." }
            return 102
          end

          hosts_and_ports_descriptions.each { |description| say "Binding #{description}..." }

          begin

            Net::SSH.start(ssh_host, app_uuid) do |ssh|
              say "Forwarding ports, use ctl + c to stop"
              hosts_and_ports.each do |host_and_port|
                host, port = host_and_port.split(/:/)
                ssh.forward.local(host, port.to_i, host, port.to_i)
              end
              ssh.loop { true }
            end

          rescue Interrupt
            say "Terminating..."
            return 0
          end

        end

      rescue Exception => e #FIXME: I am insufficiently specific
        ssh_cmd = "ssh -N "
        hosts_and_ports.each { |port| ssh_cmd << "-L #{port}:#{port} " }
        ssh_cmd << "#{app_uuid}@#{ssh_host}"
        raise RHC::Exception.new("#{e.message if options.debug}\nError trying to forward ports. You can try to forward manually by running:\n" + ssh_cmd, 1)
      end

      return 0
    end
  end
end

# mock for windows
if defined?(UNIXServer) != 'constant' or UNIXServer.class != Class then class UNIXServer; end; end

