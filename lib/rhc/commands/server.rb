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

        rhc server add openshift.redhat.com online -l personal@email.com
        rhc server add origin.openshift.mycompany.com development -l user@company.com
        rhc server add enterprise.openshift.mycompany.com production  -l user@company.com

      Then, to switch between the servers:

        rhc server use online
        rhc server use development
        rhc server use production

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
    syntax "<hostname> [<nickname>] [--rhlogin LOGIN] [--[no-]use-authorization-tokens] [--[no-]insecure]"
    argument :hostname, "Hostname of the server you are adding", ["--server HOSTNAME"]
    argument :nickname, "Optionally provide a nickname to the server you are adding (e.g. 'development', 'production', 'online')", ["--nickname NICKNAME"], :optional => true
    option ["-l", "--rhlogin LOGIN"], "Change the default OpenShift login used on this server"
    option ["--[no-]use-authorization-tokens"], "Server will attempt to create and use authorization tokens to connect to the server"
    option ["--[no-]insecure"], "If true, certificate errors will be ignored"
    option ["--skip-wizard"], "If true, the wizard will be skipped and a session token will not be estabilished"
    def add(hostname, nickname)
      server = server_configs.add(hostname, 
        :nickname                 => nickname, 
        :login                    => options.rhlogin, 
        :use_authorization_tokens => options.use_authorization_tokens, 
        :insecure                 => options.insecure,
        :timeout                  => options.timeout,
        :ssl_version              => options.ssl_version, 
        :ssl_client_cert_file     => options.ssl_client_cert_file, 
        :ssl_ca_file              => options.ssl_ca_file)

      unless options.skip_wizard
        wizard_to_server(
          server.hostname, 
          server.login, 
          server.use_authorization_tokens, 
          server.insecure,
          server.timeout,
          server.ssl_version,
          server.ssl_client_cert_file,
          server.ssl_ca_file) ? 0 : 1
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

    summary "Fast switch to change the default server"
    syntax "<server>"
    argument :server, "Server hostname or nickname to use", ["--server SERVER"]
    def use(server)
      server = server_configs.find(server)

      if wizard_to_server(server.hostname, server.login, server.use_authorization_tokens, server.insecure)
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
    syntax "<server> [--hostname HOSTNAME] [--nickname NICKNAME] [--rhlogin LOGIN] [--[no-]use-authorization-tokens] [--[no-]insecure]"
    argument :server, "Server hostname or nickname to be configured", ["--server SERVER"]
    option ["--hostname HOSTNAME"], "Change the hostname of this server"
    option ["--nickname NICKNAME"], "Change the nickname of this server"
    option ["-l", "--rhlogin LOGIN"], "Change the default OpenShift login used on this server"
    option ["--[no-]use-authorization-tokens"], "Server will attempt to create and use authorization tokens to connect to the server"
    option ["--[no-]insecure"], "If true, certificate errors will be ignored"
    def configure(server)
      server = server_configs.find(server)

      hostname = options.hostname || server.hostname
      rhlogin = options.rhlogin || server.login
      use_authorization_tokens = options.use_authorization_tokens.nil? ? server.use_authorization_tokens : options.use_authorization_tokens
      insecure = options.insecure.nil? ? server.insecure : options.insecure
      nickname = options.nickname || server.nickname
      timeout = options.timeout || server.timeout
      ssl_version = options.ssl_version || server.ssl_version
      ssl_client_cert_file = options.ssl_client_cert_file || server.ssl_client_cert_file
      ssl_ca_file = options.ssl_ca_file || server.ssl_ca_file

      raise RHC::ServerNicknameExistsException.new(options.nickname) if options.nickname && server_configs.nickname_exists?(options.nickname) && server_configs.find(options.nickname).hostname != server.hostname

      server = server_configs.update(server.hostname, 
        :hostname                 => hostname, 
        :nickname                 => nickname, 
        :login                    => rhlogin, 
        :use_authorization_tokens => use_authorization_tokens, 
        :insecure                 => insecure,
        :timeout                  => timeout,
        :ssl_version              => ssl_version, 
        :ssl_client_cert_file     => ssl_client_cert_file, 
        :ssl_ca_file              => ssl_ca_file)

      unless [options.hostname, options.rhlogin, options.use_authorization_tokens, options.insecure].all? {|x| x.nil?}
        wizard_to_server(hostname, rhlogin, use_authorization_tokens, insecure)
      end

      server_configs.save!

      paragraph{ say display_server(server) }
      paragraph { success "Now using '#{server.hostname}'" }
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
      def wizard_to_server(hostname, login=nil, use_authorization_tokens=nil, insecure=nil, timeout=nil, ssl_version=nil, ssl_client_cert_file=nil, ssl_ca_file=nil)
        options['server'] = hostname
        options['rhlogin'] = login if login
        options['use_authorization_tokens'] = use_authorization_tokens unless use_authorization_tokens.nil?
        options['insecure'] = insecure unless insecure.nil?
        options['timeout'] = timeout unless timeout.nil?
        options['ssl_version'] = ssl_version unless ssl_version.nil?
        options['ssl_client_cert_file'] = ssl_client_cert_file unless ssl_client_cert_file.nil?
        options['ssl_ca_file'] = ssl_ca_file unless ssl_ca_file.nil?
        RHC::ServerWizard.new(config, options, server_configs).run
      end

      def server_configs
        @servers ||= RHC::Servers.new(config)
      end
  end
end
