require 'rhc/commands/base'
require 'uri'

module RHC::Commands
  class ForwardingSpec
    include RHC::Helpers
    include Enumerable
    # class to specify how SSH port forwarding should be performed
    attr_accessor :remote_host, :port_to, :port_from, :bound
    attr_reader :service

    def initialize(service, remote_host, port_to, port_from = nil)
      @service     = service
      @remote_host = remote_host
      @port_to = port_to
      @port_from  = port_from || port_to # match ports if possible
      @bound       = false
    end

    def inspect
      # Use this for general description
      mac? ? "#{service}: forwarding localhost:#{port_from} to #{remote_host}:#{port_to}" :
        "#{service}: forwarding remote port #{remote_host}:#{port_to}"
    end

    def message
      # Use this for telling users when port forwarding was successful
      mac? ?  "#{service}: localhost:#{port_from} now forwards to remote port #{remote_host}:#{port_to}" :
        "#{service}: now forwarding remote port #{remote_host}:#{port_to}"
    end

    def to_cmd_arg
      # string to be used in a direct SSH command
      mac? ? " -L #{port_from}:#{remote_host}:#{port_to} " :
        " -L #{remote_host}:#{port_from}:#{remote_host}:#{port_to} "
    end

    def to_fwd_args
      # array of arguments to be passed to Net::SSH::Service::Forward#local
      args = [port_from.to_i, remote_host, port_to.to_i]
      args.unshift(remote_host) unless mac?
      args
    end

    def <=>(other)
      if @bound && !other.bound
        -1
      elsif !@bound && other.bound
        1
      else
        order_by_attrs(self, other, :service, :remote_host, :port_from)
      end
    end

    def order_by_attrs(this, other, *attrs)
      # compare _this_ and _other_ by examining their _attrs_ in order
      while attribute = attrs.shift do
        if this.send(attribute) != other.send(attribute)
          return this.send(attribute) <=> other.send(attribute)
        end
      end
      0
    end

    private :order_by_attrs
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
                  say fs.inspect
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
                    args = fs.to_fwd_args
                    debug args.inspect
                    ssh.forward.local(*args)
                    fs.bound = true
                  rescue Errno::EADDRINUSE
                    debug "trying local port #{fs.port_from}"
                    fs.port_from += 1
                  rescue Timeout::Error, Errno::EADDRNOTAVAIL, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::SSH::AuthenticationFailed => e
                    ssh_cmd = "ssh -N #{fs.to_cmd_arg} #{ssh_uri.user}@#{ssh_uri.host}"
                    warn <<-WARN
Error forwarding #{fs}. You can try to forward manually by running:
#{ssh_cmd}
                    WARN
                    given_up = true
                  end
                end
              end

              forwarding_specs.sort.each do |fs|
                say fs.message
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

