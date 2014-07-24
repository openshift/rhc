require 'rhc/servers'

module RHC::Commands
  class Server < Base
    suppress_wizard

    summary "Manage your configured servers and check the status of services"
    description <<-DESC
      The 'rhc server' commands allow users to add multiple OpenShift
      servers to interact with the rhc commands and easily switch between
      them.

      For example, if an user's company has installations of OpenShift Origin 
      (development) and Enterprise (production) and the user also has a personal
      OpenShift Online account:

        rhc add-server openshift.redhat.com online -l personal@email.com
        rhc add-server origin.openshift.mycompany.com development -l user@company.com
        rhc add-server enterprise.openshift.mycompany.com production  -l user@company.com

      Then, to switch between the servers:

        rhc use-server online
        rhc use-server development
        rhc use-server production

      To list all servers configured:

        rhc servers
      DESC
    default_action :help

    summary "Display information about the status of the OpenShift server"
    syntax "<server>"
    description <<-DESC
      Retrieves any open issues or notices about the operation of the
      OpenShift service and displays them in the order they were opened.

      When connected to an OpenShift Enterprise or Origin server, will only display
      the version of the API that it is connecting to.
      DESC
    argument :server, "Server hostname or nickname to check. If not provided the default server will be used.", ["--server SERVER"], :optional => true
    def status(server=nil)
      options.server = server.hostname if server && server = (server_configs.find(server) rescue nil)

      say "Connected to #{openshift_server}"

      if openshift_online_server?
        #status = decode_json(get("#{openshift_url}/app/status/status.json").body)
        status = rest_client.request(:method => :get, :url => "#{openshift_url}/app/status/status.json", :lazy_auth => true){ |res| decode_json(res.content) }
        open = status['open']

        (success 'All systems running fine' and return 0) if open.blank?

        open.each do |i|
          i = i['issue']
          say color("%-3s %s" % ["##{i['id']}", i['title']], :bold)
          items = i['updates'].map{ |u| [u['description'], date(u['created_at'])] }
          items.unshift ['Opened', date(i['created_at'])]
          table(items, :align => [nil,:right], :join => '  ').each{ |s| say "    #{s}" }
        end
        say "\n"
        warn pluralize(open.length, "open issue")

        open.length #exit with the count of open items
      else
        success "Using API version #{rest_client.api_version_negotiated}"
        0
      end
    end

    summary "Add a new server"
    description <<-DESC
      Add and configure a new OpenShift server that will be available to 
      use through rhc commands.
      When adding a new server users can optionally provide a 'nickname'
      that will allow to easily switch between servers. 
      DESC
    syntax "<hostname> [<nickname>] [--rhlogin LOGIN] [--[no-]use-authorization-tokens] [--[no-]insecure] [--use] [--skip-wizard] [--timeout SECONDS] [--ssl-ca-file FILE] [--ssl-client-cert-file FILE] [--ssl-version VERSION]"
    argument :hostname, "Hostname of the server you are adding", ["--server HOSTNAME"]
    argument :nickname, "Optionally provide a nickname to the server you are adding (e.g. 'development', 'production', 'online')", ["--nickname NICKNAME"], :optional => true
    option ["-l", "--rhlogin LOGIN"], "Change the default OpenShift login used on this server"
    option ["--[no-]use-authorization-tokens"], "Server will attempt to create and use authorization tokens to connect to the server"
    option ["--[no-]insecure"], "If true, certificate errors will be ignored"
    option ["--use"], "If provided, the server being added will be set as default (same as 'rhc server use')"
    option ["--skip-wizard"], "If provided, the wizard will be skipped and a session token will not be estabilished"
    option ["--timeout SECONDS"], "The default timeout for operations on this server", :type => Integer
    option ["--ssl-ca-file FILE"], "An SSL certificate CA file (may contain multiple certs) to be used on this server", :type => CertificateFile, :optional => true
    option ["--ssl-client-cert-file FILE"], "An SSL x509 client certificate file to be used on this server", :type => CertificateFile, :optional => true
    option ["--ssl-version VERSION"], "The version of SSL to use to be used on this server", :type => SSLVersion, :optional => true
    def add(hostname, nickname)
      raise ArgumentError, "The --use and --skip-wizard options cannot be used together." if options.use && options.skip_wizard

      attrs = [:login, :use_authorization_tokens, :insecure, :timeout, :ssl_version, :ssl_client_cert_file, :ssl_ca_file]

      server = server_configs.add(hostname, 
        attrs.inject({:nickname => nickname}){ |h, (k, v)| h[k] = options[k == :login ? :rhlogin : k]; h })

      unless options.skip_wizard
        (wizard_to_server(server.hostname, options.use, attrs.inject({}){ |h, (k, v)| h[k] = server.send(k); h }) ? 0 : 1).tap do |r|
          paragraph { success "Now using '#{server.hostname}'" } if options.use && r == 0
        end
      else
        say "Saving server configuration to #{system_path(server_configs.path)} ... "
        server_configs.save!
        success "done"
        0
      end
    end

    summary "List all configured servers"
    alias_action :"servers", :root_command => true
    def list
      servers = config.has_configs_from_files? ? server_configs.list : []

      servers.sort.each do |server|
        say display_server(server)
      end

      paragraph do 
        case servers.length
        when 0
          warn "You don't have any servers configured. Use 'rhc setup' to configure your OpenShift server."
        when 1
          say "You have 1 server configured. Use 'rhc server add' to add a new server."
        else
          say "You have #{servers.length} servers configured. Use 'rhc server use <hostname|nickname>' to switch between them."
        end
      end
      0
    end

    summary "Change the default server"
    syntax "<server>"
    argument :server, "Server hostname or nickname to use", ["--server SERVER"]
    def use(server)
      server = server_configs.find(server)

      attrs = [:login, :use_authorization_tokens, :insecure, :timeout, :ssl_version, :ssl_client_cert_file, :ssl_ca_file]

      if wizard_to_server(server.hostname, true, attrs.inject({}){ |h, (k, v)| h[k] = server.send(k); h })
        paragraph { success "Now using '#{server.hostname}'" }
        0
      else
        1
      end
    end

    summary "Remove a server"
    syntax "<server>"
    argument :server, "Server hostname or nickname to be removed", ["--server SERVER"]
    def remove(server)
      server = server_configs.find(server)

      say "Removing '#{server.hostname}' ... "

      if server.default?
        raise RHC::ServerInUseException.new("The '#{server.designation}' server is in use. Please switch to another server before removing it.")
      else
        server_configs.remove(server.hostname)
        server_configs.save!
      end

      success "done"
      0
    end

    summary "Update server attributes"
    syntax "<server> [--hostname HOSTNAME] [--nickname NICKNAME] [--rhlogin LOGIN] [--[no-]use-authorization-tokens] [--[no-]insecure] [--use] [--skip-wizard] [--timeout SECONDS] [--ssl-ca-file FILE] [--ssl-client-cert-file FILE] [--ssl-version VERSION]"
    argument :server, "Server hostname or nickname to be configured", ["--server SERVER"]
    option ["--hostname HOSTNAME"], "Change the hostname of this server"
    option ["--nickname NICKNAME"], "Change the nickname of this server"
    option ["-l", "--rhlogin LOGIN"], "Change the default OpenShift login used on this server"
    option ["--[no-]use-authorization-tokens"], "Server will attempt to create and use authorization tokens to connect to the server"
    option ["--[no-]insecure"], "If true, certificate errors will be ignored"
    option ["--use"], "If provided, the server being configured will be set as default (same as 'rhc server use')"
    option ["--skip-wizard"], "If provided, the wizard will be skipped and a session token will not be estabilished"
    option ["--timeout SECONDS"], "The default timeout for operations on this server", :type => Integer
    option ["--ssl-ca-file FILE"], "An SSL certificate CA file (may contain multiple certs) to be used on this server", :type => CertificateFile, :optional => true
    option ["--ssl-client-cert-file FILE"], "An SSL x509 client certificate file to be used on this server", :type => CertificateFile, :optional => true
    option ["--ssl-version VERSION"], "The version of SSL to use to be used on this server", :type => SSLVersion, :optional => true
    def configure(server)
      raise ArgumentError, "The --use and --skip-wizard options cannot be used together." if options.use && options.skip_wizard

      server = server_configs.find(server)

      attrs = [:hostname, :nickname, :login, :use_authorization_tokens, :insecure, :timeout, :ssl_version, :ssl_client_cert_file, :ssl_ca_file].inject({}){ |h, (k, v)| v = options[k == :login ? :rhlogin : k]; h[k] = (v.nil? ? server.send(k) : v); h }

      raise RHC::ServerNicknameExistsException.new(options.nickname) if options.nickname && 
        server_configs.nickname_exists?(options.nickname) && 
        server_configs.find(options.nickname).hostname != server.hostname

      server = server_configs.update(server.hostname, attrs)

      unless options.skip_wizard
        wizard_to_server(attrs[:hostname], options.use, attrs.reject{|k, v| k == :hostname || k == :nickname})
      else
        say "Saving server configuration to #{system_path(server_configs.path)} ... "
        server_configs.save!
        success "done"
        0
      end

      paragraph{ say display_server(server) }
      paragraph { success "Now using '#{server.hostname}'" } if options.use
      0
    end

    summary "Display the configuration of the given server"
    syntax "<server>"
    argument :server, "Server hostname or nickname to be displayed", ["--server SERVER"]
    def show(server)
      server = server_configs.find(server)
      say display_server(server)
      paragraph{ say "Use 'rhc servers' to display all your servers." } if server_configs.list.length > 1
      0
    end

    protected
      def wizard_to_server(hostname, set_default, args)
        options['server'] = hostname
        options['rhlogin'] = args[:login] if args[:login]
        options['use_authorization_tokens'] = args[:use_authorization_tokens] unless args[:use_authorization_tokens].nil?
        options['create_token'] = args[:use_authorization_tokens] unless args[:use_authorization_tokens].nil?
        options['insecure'] = args[:insecure] unless args[:insecure].nil?
        options['timeout'] = args[:timeout]
        options['ssl_version'] = args[:ssl_version]
        options['ssl_client_cert_file'] = args[:ssl_client_cert_file]
        options['ssl_ca_file'] = args[:ssl_ca_file]
        RHC::ServerWizard.new(config, options, server_configs, set_default).run
      end

      def server_configs
        @servers ||= RHC::Servers.new(config)
      end
  end
end
