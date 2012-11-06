require 'rhc/commands/base'
require 'uri'

module RHC::Commands
  class ForwardingSpec
    include RHC::Helpers
    # class to specify how SSH port forwarding should be performed
    attr_accessor :remote_host, :remote_port, :local_port, :bound
    attr_reader :service

    def initialize(service, remote_host, remote_port, local_port = nil)
      @service     = service
      @remote_host = remote_host
      @remote_port = remote_port
      @local_port  = local_port || remote_port # match ports if possible
      @bound       = false
    end

    def inspect
      "#{service}: forwarding local port #{local_port} to #{remote_host}:#{remote_port}"
    end

    def to_cmd_arg
      # string to be used in a direct SSH command
      mac? ? " -L #{local_port}:#{remote_host}:#{remote_port} " :
        " -L #{remote_host}:#{local_port}:#{remote_host}:#{remote_port} "
    end

    def to_fwd_args
      # array of arguments to be passed to Net::SSH::Service::Forward#local
      args = [local_port.to_i, remote_host, remote_port.to_i]
      args.unshift(remote_host) unless mac?
      args
    end

  end

  class PortForward < Base

    UP_TO_256 = /25[0-5]|2[0-4][0-9]|[01]?(?:[0-9][0-9]?)/
    UP_TO_65535 = /6553[0-5]|655[0-2][0-9]|65[0-4][0-9][0-9]|6[0-4][0-9][0-9][0-9]|[0-5]?(?:[0-9][0-9]{0,3})/
    IP_AND_PORT = /\b(#{UP_TO_256}(?:\.#{UP_TO_256}){3})\:(#{UP_TO_65535})\b/

    summary "Forward remote ports to the workstation"
    option ["-n", "--namespace namespace"], "Namespace of the application you are port forwarding to", :context => :namespace_context, :required => true
    argument :app, "Application you are port forwarding to (required)", ["-a", "--app app"]
    def run(app)

      rest_domain = rest_client.find_domain options.namespace
      rest_app = rest_domain.find_application app

      #raise RHC::ScaledApplicationsNotSupportedException.new "This utility does not currently support scaled applications. You will need to set up port forwarding manually." if rest_app.scalable?

      ssh_uri = URI.parse(rest_app.ssh_url)
      say "Using #{rest_app.ssh_url}..." if options.debug

      hosts_and_ports = []
      hosts_and_ports_descriptions = []

      forwarding_specs = []

      begin

        say "Checking available ports..."

        Net::SSH.start(ssh_uri.host, ssh_uri.user) do |ssh|
          debug "starting"

          ssh.exec! "rhc-list-ports" do |channel, stream, data|
            if stream == :stderr
              data.each_line do |line|
                line.chomp!
                raise RHC::PermissionDeniedException.new "Permission denied." if line =~ /permission denied/i
                if line =~ /\A\s*(\S+) -> #{IP_AND_PORT}/
                  debug fs = ForwardingSpec.new($1, $2, $3.to_i)
                  say "Forwarding #{fs.inspect}"
                  forwarding_specs << fs
                else
                  debug line
                end

              end
            else
#              data.each_line do |line|
#                line.chomp!
#                if ((not line =~ /scale/i) and IP_AND_PORT.match(line))
#                  hosts_and_ports << line 
#                  host, port = line.split /:/
#                  forwarding_specs << ForwardingSpec.new(host, port.to_i)
#                end
#              end
            end
          end

          raise RHC::NoPortsToForwardException.new "There are no available ports to forward for this application. Your application may be stopped." if forwarding_specs.length == 0

          hosts_and_ports_descriptions.each { |description| say "Binding #{description}..." }

          begin
            Net::SSH.start(ssh_uri.host, ssh_uri.user) do |ssh|
              say "Forwarding ports, use ctl + c to stop"
#              hosts_and_ports.each do |host_and_port|
#                host, port = host_and_port.split(/:/)
#                args = [port.to_i, host, port.to_i]
#                args.unshift(host) unless mac?
#                ssh.forward.local(*args)
#              end
              forwarding_specs.each do |fs|
                given_up = nil
                while !fs.bound && ! given_up
                  begin
                    raise Errno::EADDRNOTAVAIL
                    args = fs.to_fwd_args
                    debug args.inspect
                    ssh.forward.local(*args)
                    fs.bound = true
                    say "#{fs.service}: local port #{fs.local_port} now forwards to remote port #{fs.remote_port} on #{fs.remote_host}"
                  rescue Errno::EADDRINUSE
                    debug "trying local port #{fs.local_port}"
                    fs.local_port += 1
                  rescue Timeout::Error, Errno::EADDRNOTAVAIL, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::SSH::AuthenticationFailed => e
                    ssh_cmd = "ssh -N #{fs.to_cmd_arg} #{ssh_uri.user}@#{ssh_uri.host}"
                    warn <<-WARN
Error forwarding local port #{fs.local_port} to remote port #{fs.remote_port} on #{fs.remote_host}.
You can try to forward manually by running:
#{ssh_cmd}
                    WARN
                    given_up = true
                  end
                end
              end
              unless forwarding_specs.any? {|conn| conn.bound }
                warn "No ports have been bound"
                raise Interrupt
              end
              ssh.loop { true }
            end
          rescue Interrupt
            results { say "Ending port forward" }
            return 0
          end

        end

      rescue Timeout::Error, Errno::EADDRNOTAVAIL, Errno::EADDRINUSE, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::SSH::AuthenticationFailed => e
        ssh_cmd = "ssh -N "
        hosts_and_ports.each do |desc|
          host, port = desc.split(/:/)
          port_spec = mac? ? "-L #{port}:#{host}:#{port} " : "-L #{host}:#{port}:#{host}:#{port} "
          ssh_cmd << port_spec
        end
        ssh_cmd << "#{ssh_uri.user}@#{ssh_uri.host}"
        raise RHC::PortForwardFailedException.new("#{e.message if options.debug}\nError trying to forward ports. You can try to forward manually by running:\n" + ssh_cmd)
      end

      return 0
    end
  end
end

# mock for windows
if defined?(UNIXServer) != 'constant' or UNIXServer.class != Class then class UNIXServer; end; end

