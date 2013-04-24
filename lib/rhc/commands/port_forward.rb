require 'rhc/commands/base'
require 'uri'

module RHC::Commands
  class ForwardingSpec
    include RHC::Helpers
    include Enumerable
    # class to represent how SSH port forwarding should be performed
    attr_accessor :port_from
    attr_reader :remote_host, :port_to, :host_from, :service
    attr_writer :bound

    def initialize(service, remote_host, port_to, port_from = nil)
      @service     = service
      @remote_host = remote_host
      @port_to     = port_to
      @host_from   = '127.0.0.1'
      @port_from   = port_from || port_to # match ports if possible
      @bound       = false
    end

    def to_cmd_arg
      # string to be used in a direct SSH command
      "-L #{port_from}:#{remote_host}:#{port_to}"
    end

    def to_fwd_args
      # array of arguments to be passed to Net::SSH::Service::Forward#local
      [port_from.to_i, remote_host, port_to.to_i]
    end

    def bound?
      @bound
    end

    # :nocov: These are for sorting. No need to test for coverage.
    def <=>(other)
      if bound? && !other.bound?
        -1
      elsif !bound? && other.bound?
        1
      else
        order_by_attrs(other, :service, :remote_host, :port_from)
      end
    end

    def order_by_attrs(other, *attrs)
      # compare self and "other" by examining their "attrs" in order
      # attrs should be an array of symbols to which self and "other"
      # respond when sent.
      while attribute = attrs.shift do
        if self.send(attribute) != other.send(attribute)
          return self.send(attribute) <=> other.send(attribute)
        end
      end
      0
    end
    # :nocov:

    private :order_by_attrs
  end

  class PortForward < Base

    UP_TO_256 = /25[0-5]|2[0-4][0-9]|[01]?(?:[0-9][0-9]?)/
    UP_TO_65535 = /6553[0-5]|655[0-2][0-9]|65[0-4][0-9][0-9]|6[0-4][0-9][0-9][0-9]|[0-5]?(?:[0-9][0-9]{0,3})/
    # 'host' part is a bit lax; we rely on 'rhc-list-ports' to hand us a reasonable output
    # about the host information, be it numeric or FQDN in IPv4 or IPv6.
    HOST_AND_PORT = /(.+):(#{UP_TO_65535})\b/

    summary "Forward remote ports to the workstation"
    syntax "<application>"
    option ["-n", "--namespace NAME"], "Namespace of the application you are port forwarding to", :context => :namespace_context, :required => true
    argument :app, "Application you are port forwarding to (required)", ["-a", "--app NAME"]
    option ["-g", "--gear ID"], "Gear ID you are port forwarding to (optional)", :required => false
    def run(app)
      rest_app = rest_client.find_application(options.namespace, app)
      ssh_uri = URI.parse(options.gear ? rest_app.gear_ssh_url(options.gear) : rest_app.ssh_url)

      say "Using #{ssh_uri}..." if options.debug

      forwarding_specs = []

      begin
        say "Checking available ports ... "

        Net::SSH.start(ssh_uri.host, ssh_uri.user) do |ssh|
          ssh.exec! "rhc-list-ports" do |channel, stream, data|
            if stream == :stderr
              data.each_line do |line|
                line.chomp!
                # FIXME: This is really brittle; there must be a better way
                # for the server to tell us that permission (what permission?)
                # is denied.
                raise RHC::PermissionDeniedException.new "Permission denied." if line =~ /permission denied/i
                # ...and also which services are available for the application
                # for us to forward ports for.
                if line =~ /\A\s*(\S+) -> #{HOST_AND_PORT}\z/
                  debug fs = ForwardingSpec.new($1, $2, $3.to_i)
                  forwarding_specs << fs
                else
                  debug line
                end

              end
            end
          end

          if forwarding_specs.length == 0
            # check if the gears have been stopped
            ggs = rest_app.gear_groups
            if ggs.any? { |gg|
              gears = gg.gears
              true if gears.any? { |g| g["state"] == "stopped" }
            }
              warn "Application #{rest_app.name} is stopped. Please restart the application and try again."
              return 1
            else
              raise RHC::NoPortsToForwardException.new "There are no available ports to forward for this application. Your application may be stopped."
            end
          end

          success "done"

          begin
            Net::SSH.start(ssh_uri.host, ssh_uri.user) do |ssh|
              say "Forwarding ports ..."
              forwarding_specs.each do |fs|
                given_up = nil
                while !fs.bound? && !given_up
                  begin
                    args = fs.to_fwd_args
                    debug args.inspect
                    ssh.forward.local(*args)
                    fs.bound = true
                  rescue Errno::EADDRINUSE, Errno::EACCES => e
                    warn "#{e} while forwarding port #{fs.port_from}. Trying local port #{fs.port_from+1}"
                    fs.port_from += 1
                  rescue Timeout::Error, Errno::EADDRNOTAVAIL, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::SSH::AuthenticationFailed => e
                    given_up = true
                  end
                end
              end

              bound_ports = forwarding_specs.select(&:bound?)
              if bound_ports.length > 0
                paragraph{ say "To connect to a service running on OpenShift, use the Local address" }
                paragraph do
                  say table(
                        bound_ports.map do |fs|
                          [fs.service, "#{fs.host_from}:#{fs.port_from}", " => ", "#{fs.remote_host}:#{fs.port_to.to_s}"]
                        end,
                        :header => ["Service", "Local", "    ", "OpenShift"]
                      )
                end
              end

              # for failed port forwarding attempts
              failed_port_forwards = forwarding_specs.select { |fs| !fs.bound? }
              if failed_port_forwards.length > 0
                ssh_cmd_arg = failed_port_forwards.map { |fs| fs.to_cmd_arg }.join(" ")
                ssh_cmd = "ssh -N #{ssh_cmd_arg} #{ssh_uri.user}@#{ssh_uri.host}"
                warn "Error forwarding some port(s). You can try to forward manually by running:\n#{ssh_cmd}"
              else
                say "Press CTRL-C to terminate port forwarding"
              end

              unless forwarding_specs.any?(&:bound?)
                warn "No ports have been bound"
                return
              end
              ssh.loop { true }
            end
          rescue Interrupt
            say " Ending port forward"
            return 0
          end

        end

      rescue Timeout::Error, Errno::EADDRNOTAVAIL, Errno::EADDRINUSE, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::SSH::AuthenticationFailed => e
        ssh_cmd = ["ssh","-N"]
        unbound_fs = forwarding_specs.select { |fs| !fs.bound? }
        ssh_cmd += unbound_fs.map { |fs| fs.to_cmd_arg }
        ssh_cmd += ["#{ssh_uri.user}@#{ssh_uri.host}"]
        raise RHC::PortForwardFailedException.new("#{e.message + "\n" if options.debug}Error trying to forward ports. You can try to forward manually by running:\n" + ssh_cmd.join(" "))
      end

      0
    rescue RHC::Rest::ConnectionException => e
      error "Connection to #{openshift_server} failed: #{e.message}"
      1
    end
  end
end

# mock for windows
if defined?(UNIXServer) != 'constant' or UNIXServer.class != Class then class UNIXServer; end; end

