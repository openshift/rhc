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
    include RHC::SSHHelpers

    UP_TO_256 = /25[0-5]|2[0-4][0-9]|[01]?(?:[0-9][0-9]?)/
    UP_TO_65535 = /6553[0-5]|655[0-2][0-9]|65[0-4][0-9][0-9]|6[0-4][0-9][0-9][0-9]|[0-5]?(?:[0-9][0-9]{0,3})/
    # 'host' part is a bit lax; we rely on 'rhc-list-ports' to hand us a reasonable output
    # about the host information, be it numeric or FQDN in IPv4 or IPv6.
    HOST_AND_PORT = /(.+):(#{UP_TO_65535})\b/

    summary "Forward remote ports to the workstation"
    syntax "<application>"
    takes_application :argument => true
    option ["-g", "--gear ID"], "Gear ID you are port forwarding to (optional)"
    option ["-s", "--service [SERVICE,]"], "A CSV list of services to port forward (optional)"
    def run(app)
      ssh_executable = check_ssh_executable! options.ssh
      forwarding_specs = []

      begin
        rest_app = find_app
        ssh_uri = URI.parse(options.gear ? rest_app.gear_ssh_url(options.gear) : rest_app.ssh_url)
        debug "Using #{ssh_uri}..."

        output = ""
        say "Checking available ports ... "

        list_ports_cmd = "rhc-list-ports#{options.gear ? ' --exclude-remote' : ''}"
        # Only use Net::SSH if no ssh executable is specified
        if !options.ssh
          Net::SSH.start(ssh_uri.host, ssh_uri.user) do |ssh|
            # If a specific gear is targeted, do not include remote (e.g. database) ports
            ssh.exec! list_ports_cmd do |channel, stream, data|
              if stream == :stderr
                output << data
              end
            end
          end
        else
          ssh_cmd = "#{ssh_executable} #{ssh_uri.user}@#{ssh_uri.host} '#{list_ports_cmd} 2>&1'"
          debug "Running #{ssh_cmd} to determine forwarding ports."
          begin
            status, output = run_with_system_ssh(ssh_cmd)
          rescue RHC::SSHCommandFailed => e
            ex_forward_cmd = "#{ssh_executable} -N -L <local_port>:<gear_ip>:<destination_port> #{rest_app.ssh_url.gsub("ssh://", "")}"
            raise RHC::PortForwardFailedException.new("#{e.message + "\n" if debug?}Error attempting to collect ports to forward from app. You can try to forward ports manually.\nFirst, to get the destination ip and port, run the following command:\n  #{ssh_cmd}\nThen, run the following command with the ports and ip substituted:\n  " + ex_forward_cmd)
          end
        end

        output.each_line do |line|
          line.chomp!
          # FIXME: This is really brittle; there must be a better way
          # for the server to tell us that permission (what permission?)
          # is denied.
          raise RHC::PermissionDeniedException.new "Permission denied." if line =~ /permission denied/i
          # ...and also which services are available for the application
          # for us to forward ports for.
          if line =~ /\A\s*(\S+) -> #{HOST_AND_PORT}\z/ and (options.service.nil? or options.service.empty? or options.service.split(',').include? $1)
            debug "Found service #{$1} with remote host #{$2} and port #{$3}"
            fs = ForwardingSpec.new($1, $2, $3.to_i)
            forwarding_specs << fs
          else
            debug line
          end
        end

        if forwarding_specs.length == 0
          # check if the gears have been stopped
          if rest_app.gear_groups.all?{ |gg| gg.gears.all?{ |g| g["state"] == "stopped" } }
            warn "none"
            error "The application is stopped. Please restart the application and try again."
            return 1
          else
            warn "none"
            raise RHC::NoPortsToForwardException.new "There are no available ports to forward for this application. Your application may be stopped or idled."
          end
        end

        success "done"

        begin
          # if an ssh executable was specified, provide the command that be can run, assuming that the
          # ssh executable's flags and options are the same as openssh's flags
          if options.ssh
            ssh_cmd_arg = forwarding_specs.map { |fs| fs.to_cmd_arg }.join(" ")
            ssh_cmd = "#{ssh_executable} -N #{ssh_cmd_arg} #{ssh_uri.user}@#{ssh_uri.host}"
            warn "You can try forwarding ports manually by running the command:\n  #{ssh_cmd}"
            raise RHC::ArgumentNotValid.new("A SSH executable is specified and cannot be used with this command.")
          else
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
                  rescue Errno::EADDRINUSE, Errno::EACCES, Errno::EPERM => e
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
          end
        rescue Interrupt
          say " Ending port forward"
          return 0
        end

      rescue Timeout::Error, Errno::EADDRNOTAVAIL, Errno::EADDRINUSE, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::SSH::AuthenticationFailed => e
        ssh_cmd = [ssh_executable,"-N"]
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

