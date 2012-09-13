require 'rhc/commands/base'
require 'resolv'
require 'rhc/git_helper'

module RHC::Commands
  class App < Base
    summary "Commands for creating and managing applications"
    description "Creates and controls an OpenShift application.  To see the list of all applications use the rhc domain show command.  Note that delete is not reversible and will stop your application and then remove the application and repo from the remote server. No local changes are made."
    syntax "<action>"
    default_action :help

    summary "Create an application and adds it to a domain"
    syntax "<name> <cartridge> [... <other cartridges>][--namespace namespace]"
    option ["-n", "--namespace namespace"], "Namespace to add your application to", :context => :namespace_context, :required => true
    option ["-g", "--gear-size size"], "The  size  of the gear for this app. Available gear sizes depend on the type of account you have."
    option ["-r", "--repo dir"], "Git Repo path (defaults to ./$app_name) (applicable to the  create command)"
    option ["--no-git", "--nogit"], "Only  create  remote space, don't pull it locally"
    option ["--no-dns", "--nodns"], "Skip DNS check. Must be used in combination with --nogit"
    option ["--enable-jenkins [server_name]"], "Indicates to create a Jenkins application (if not already available)  and  embed the Jenkins client into this application. The default name will be 'jenkins' if not specified. Note that --nodns is ignored for the creation of the Jenkins application."
    argument :name, "The name you wish to give your application", ["-a", "--app name"]
    argument :cartridge, "The first cartridge added to the application. Usually a web framework", ["-t", "--type cartridge"]
    argument :additional_cartridges, "A list of other cartridges such as databases you wish to add. Cartridges can also be added later using 'rhc cartridge add'", [], :arg_type => :list
    def create(name, cartridge, additional_cartridges)
      warnings = []
      say "Creating '#{name}' application in domain '#{options.namespace}' with cartridge '#{cartridge}'"
      rest_domain = rest_client.find_domain(options.namespace)

      # check to make sure the right options are set for enabling jenkins
      jenkins_rest_app = check_jenkins(name, rest_domain) if options.enable_jenkins

      # create the main app
      rest_app = create_app(name, cartridge, rest_domain,
                            options.gear_size, options.scaling)

      # create a jenkins app if not available
      # don't error out if there are issues, setup warnings instead
      begin
        jenkins_rest_app = setup_jenkins_app(rest_domain) if options.enable_jenkins and jenkins_rest_app.nil?
      rescue Exception => e
        warnings << <<WARNING
Jenkins failed to install - #{e}
You may use these commands to create the jenkins app and install the client:

  rhc app create jenkins
  rhc cartridge add jenkins-client -a #{rest_app.name}

WARNING
      end

      # add jenkins-client cart
      begin
        setup_jenkins_client(rest_app) if jenkins_rest_app
      rescue Exception => e
        warnings << <<WARNING
Jenkins client failed to install in your application - #{e}
You may use this command to add the client to your application

  rhc cartridge add jenkins-client -a #{rest_app.name}

WARNING
      end

      unless options.nodns
        unless dns_propagated? rest_app.host
          warnings << <<WARNING
We were unable to lookup your hostname (#{rest_app.host}) in a reasonable amount of time.
This can happen periodically and will just take an extra minute or two to
propagate depending on where you are in the world. Once you are able to access
your application in a browser, you can run this command to clone your application.

  git clone #{rest_app.git_url} \"#{options.repo}\""

WARNING
          print_warnings(rest_app, warnings)
          return 0
        end

        unless options.nogit
          begin
            run_git_clone(rest_app)
          rescue RHC::GitException => e
            if RHC::Helpers.windows? and warning = windows_nslookup_bug?
              warnings << warning
            elseit
              warnings << <<WARNING
#{e}
You can use this command to clone your application locally

  git clone #{rest_app.git_url} \"#{options.repo}\"

WARNING
            end
          end
        end
      end

      unless warnings.empty?
        print_warnings(rest_app, warnings)
      else
        results { say "Success!" }
      end

      0
    end

    summary "Clone and configure an application's repository locally"
    description "This is a convenience wrapper for 'git clone' with the added",
                "benefit of adding configuration data such as the application's",
                "UUID to the local repository.  It also automatically",
                "figures out the git url from the application name so you don't",
                "have to look it up."
    syntax "<app> [--namespace namespace]"
    option ["-n", "--namespace namespace"], "Namespace to add your application to", :context => :namespace_context, :required => true
    argument :app, "The application you wish to clone", ["-a", "--app name"]
    # TODO: Implement default values for arguments once ffranz has added context arguments
    # argument :directory, "The name of a new directory to clone into", [], :default => nil
    def git_clone(app)
      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(app)
      run_git_clone(rest_app)
    end

    private
      include RHC::GitHelpers

      def create_app(name, cartridge, rest_domain, gear_size=nil, scaling=nil)
        app_options = {:cartridge => cartridge}
        app_options[:gear_profile] = gear_size if gear_size
        app_options[:scaling] = scaling if scaling
        app_options[:debug] = true if @debug

        debug "Creating application '#{name}' with these options - #{app_options}.inspect"

        rest_app = rest_domain.add_application(name, app_options)

        debug "'#{rest_app.name}' created"

        rest_app
      end

      def dns_propagated?(host)
        #
        # Confirm that the host exists in DNS
        #
        puts "Your application's domain name is being propagated worldwide (this might take a minute)..."
        debug "Start checking for application dns @ '#{host}'"

        found = false

        # Allow DNS to propagate
        sleep 5

        # Now start checking for DNS
        sleep_time = 2
        for i in 0..MAX_RETRIES-1
          found = host_exist?(host)
          break if found

          say "    retry # #{i+1} - Waiting for DNS: #{host}"
          sleep sleep_time.to_i
          sleep_time *= DEFAULT_DELAY_THROTTLE
        end

        debug "End checking for application dns @ '#{host} - found=#{found}'"

        found
      end

      def host_exist?(host)
        dns = Resolv::DNS.new
        dns.getresources(host, Resolv::DNS::Resource::IN::A).any?
      end

      def check_sshkeys!
        wizard = RHC::SSHWizard.new(config.username, config.password)
        wizard.run
      end

      def run_git_clone(rest_app)
        debug "Pulling new repo down"

        check_sshkeys! unless options.noprompt

        repo_dir = options.repo || rest_app.name
        clone_repo rest_app.git_url, repo_dir

        configure_git rest_app

        true
      end

      def configure_git(rest_app)
        debug "Configuring git repo"

        repo_dir = options.repo || rest_app.name
        Dir.chdir(repo_dir) do |dir|
          git_config_set "rhc.app-uuid", rest_app.uuid
        end
      end

      def jenkins_app_name
        return "jenkins" if options.enable_jenkins == true or options.enable_jenkins == "true"
        return options.enable_jenkins if options.enable_jenkins.is_a(String)
        nil
      end

      def check_jenkins(app_name, rest_domain)
        debug "Checking if jenkins arguments are valid"
        raise ArgumentError, "The --nodns option can't be used in conjunction with --enable-jenkins when creating an application.  Either remove the --nodns option or first install your application with --nodns and then use 'rhc cartridge add' to embed the Jenkins client." if options.nodns


        begin
          jenkins_rest_app = rest_domain.find_application(:framework => "jenkins-1.4")
        rescue RHC::ApplicationNotFoundException
          debug "No Jenkins apps found during check"

          # app name and jenkins app name are the same
          raise ArgumentError, "You have named both your main application and your Jenkins application '#{app_name}'. In order to continue you'll need to specify a different name with --enable-jenkins or choose
a different application name." if jenkins_app_name == app_name

          # jenkins app name and existing app are the same
          begin
            rest_app = rest_domain.find_application(:name => jenkins_app_name)
            raise ArgumentError, "You have named your Jenkins application the same as an existing application '#{app_name}'. In order to continue you'll need to specify a different name with --enable-jenkins or delete the current application using 'rhc app delete #{app_name}'"
          rescue RHC::ApplicationNotFoundException
          end

          debug "Jenkins arguments valid"
          return nil
        end

        say "Found existing Jenkins application: #{jenkins_rest_app.name}"
        say "Ignoring user specified Jenkins app name : #{options.enable_jenkins}" if jenkins_rest_app.name != options.enable_jenkins and options.enable_jenkins.is_a?(String)

        debug "Jenkins arguments valid"
        jenkins_rest_app
      end

      def setup_jenkins_app(rest_domain)
        debug "Creating a new jenkins application"
        rest_app = create_app(jenkins_app_name, "jenkins-1.4", rest_domain)

        # If we can't get the dns we can't install the client so return nil
        dns_propagated?(rest_app.host) ? rest_app : nil

      end
      def setup_jenkins_client(rest_app)
        rest_app.add_cartridge("jenkins-client-1.4")
      end

      def windows_nslookup_bug?(rest_app)
        `nslookup #{rest_app.host}`
        windows_nslookup = $?.exitstatus == 0
        `ping #{rest_app.host}-n 2`
        windows_ping = $?.exitstatus == 0

        if windows_nslookup and !windows_ping # this is related to BZ #826769
          warning <<WINSOCKISSUE
We were unable to lookup your hostname (#{rest_app.host})
in a reasonable amount of time.  This can happen periodically and will just
take up to 10 extra minutes to propagate depending on where you are in the
world. This may also be related to an issue with Winsock on Windows [1][2].
We recommend you wait a few minutes then clone your git repository manually with
this command:

    git clone #{rest_app.git_url} "#{options.repo}"

[1] http://support.microsoft.com/kb/299357
[2] http://support.microsoft.com/kb/811259

WINSOCKISSUE
          return warning
        end

        false
      end

      def print_warnings(rest_app, warnings)
        warn <<WARNING
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 WARNING:  Some operations did not complete and your application may not be fully
configured.  Bellow are a list of the warnings and commands you may use to
complete your application's configuration

  Application URL: #{rest_app.app_url}

WARNING

        warnings.each { |w| warn w }
        warn "\n"

        warn <<WARNING
If you can't get your application '#{rest_app.name}' running in the browser, you can
also try destroying and recreating the application as well using:

  rhc app destroy #{rest_app.name} --confirm

If this doesn't work for you, let us know in the forums or in IRC and we'll
make sure to get you up and running.

  Forums: https://openshift.redhat.com/community/forums/openshift

  IRC: #openshift (on Freenode)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

WARNING
      end
  end
end
