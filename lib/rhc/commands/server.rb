require 'rhc/servers'

module RHC::Commands
  class Server < Base
    suppress_wizard

    summary "Manage your configured servers and check the status of services"
    description <<-DESC
      The 'rhc server' commands allow users to add multiple OpenShift
      servers to interact through the rhc commands and easily switch between
      them.

      For example, if an user's company have installations of OpenShift Origin 
      (development) and Enterprise (production) and the user also has a personal
      OpenShift Online account:

        rhc server add openshift.redhat.com online -l personal@email.com
        rhc server add origin.openshift.mycompany.com development -l user@company.com
        rhc server add enterprise.openshift.mycompany.com production  -l user@company.com

      Then to switch between the servers:

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
    discard_global_option "--server"
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
      use through the rhc commands.
      When adding a new server users can optionally provide a 'nickname'
      that will allow to easily switch and identify servers. 
      DESC
    syntax "<hostname> [<nickname>] [--rhlogin LOGIN] [--[no-]use-authorization-tokens] [--[no-]insecure]"
    discard_global_option "--server"
    discard_global_option "-l", "--rhlogin"
    argument :hostname, "Hostname of the server you are adding", ["--hostname HOSTNAME"]
    argument :nickname, "Optionally provide a nickname to the server you are adding (e.g. 'development', 'production', 'online')", ["--nickname NICKNAME"], :optional => true
    option ["-l", "--rhlogin LOGIN"], "Change the default OpenShift login used on this server"
    option ["--[no-]use-authorization-tokens"], "Server will attempt to create and use authorization tokens to connect to the server"
    option ["--[no-]insecure"], "If true, certificate errors will be ignored"
    def add(hostname, nickname)
      server = server_configs.add(hostname, 
        :nickname => nickname, 
        :login => options.login, 
        :use_authorization_tokens => options.use_authorization_tokens, 
        :insecure => options.insecure)

      wizard_to_server(
        server.hostname, 
        server.login, 
        server.use_authorization_tokens, 
        server.insecure) ? 0 : 1
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
          warn "You don't have servers configured. Use 'rhc setup' to configure your OpenShift server."
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
    discard_global_option "--server"
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
    discard_global_option "--server"
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
    discard_global_option "--server"
    discard_global_option "-l", "--rhlogin"
    argument :server, "Server hostname or nickname to be configured", ["--server SERVER"]
    option ["--hostname HOSTNAME"], "Change the hostname of this server"
    option ["--nickname NICKNAME"], "Change the nickname of this server"
    option ["-l", "--rhlogin LOGIN"], "Change the default OpenShift login used on this server"
    option ["--[no-]use-authorization-tokens"], "Server will attempt to create and use authorization tokens to connect to the server"
    option ["--[no-]insecure"], "If true, certificate errors will be ignored"
    def configure(server)
      server = server_configs.find(server)

      hostname = options.__explicit__[:hostname]
      rhlogin = options.__explicit__[:rhlogin]
      use_authorization_tokens = options.__explicit__[:use_authorization_tokens]
      insecure = options.__explicit__[:insecure]
      nickname = options.__explicit__[:nickname]

      say "Updating configuration of server '#{server.hostname}' ... "
      server = server_configs.update(server.hostname, 
        :hostname => hostname || server.hostname, 
        :nickname => nickname || server.nickname, 
        :login => rhlogin || server.login, 
        :use_authorization_tokens => use_authorization_tokens || server.use_authorization_tokens, 
        :insecure => insecure || server.insecure)
      server_configs.save!
      success "done"

      unless [hostname, rhlogin, use_authorization_tokens, insecure].all? {|x| x.nil?}
        wizard_to_server(
          hostname || server.hostname, 
          rhlogin || server.login, 
          use_authorization_tokens || server.use_authorization_tokens, 
          insecure || server.insecure)
      end

      paragraph{ say display_server(server) }
      0
    end

    summary "Display the configuration of the given server"
    syntax "<server>"
    discard_global_option "--server"
    argument :server, "Server hostname or nickname to be displayed", ["--server SERVER"]
    def show(server)
      server = server_configs.find(server)
      say display_server(server)
      paragraph{ say "Use 'rhc servers' to display all your servers." } if server_configs.list.length > 1
      0
    end

    protected
      def wizard_to_server(hostname, login=nil, use_authorization_tokens=nil, insecure=nil)
        options['server'] = hostname
        options['rhlogin'] = login if login
        options['use_authorization_tokens'] = use_authorization_tokens unless use_authorization_tokens.nil?
        options['insecure'] = insecure unless insecure.nil?
        RHC::ServerWizard.new(config, options, server_configs).run
      end

      def server_configs
        @servers ||= RHC::Servers.new(config)
      end
  end
end
