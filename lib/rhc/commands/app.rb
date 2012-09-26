require 'rhc/commands/base'
require 'resolv'
require 'rhc/git_helper'
require 'rhc/cartridge_helper'

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
    option ["-s", "--scaling"], "Enable scaling for this application"
    option ["-r", "--repo dir"], "Git Repo path (defaults to ./$app_name) (applicable to the  create command)"
    option ["--[no-]git"], "Only  create  remote space, don't pull it locally"
    option ["--nogit"], "DEPRECATED! Only  create  remote space, don't pull it locally", :deprecated => {:key => :git, :value => false}
    option ["--[no-]dns"], "Skip DNS check. Must be used in combination with --no-git"
    option ["--enable-jenkins [server_name]"], "Indicates to create a Jenkins application (if not already available)  and  embed the Jenkins client into this application. The default name will be 'jenkins' if not specified. Note that --no-dns is ignored for the creation of the Jenkins application."
    argument :name, "The name you wish to give your application", ["-a", "--app name"]
    argument :cartridge, "The first cartridge added to the application. Usually a web framework", ["-t", "--type cartridge"]
    argument :additional_cartridges, "A list of other cartridges such as databases you wish to add. Cartridges can also be added later using 'rhc cartridge add'", [], :arg_type => :list
    def create(name, cartridge, additional_cartridges)
      options.default \
        :dns => true,
        :git => true

      warnings = []
      header "Creating application '#{name}'"
      paragraph do
        table({"Namespace:" => options.namespace,
               "Cartridge:" => cartridge,
               "Gear Size:" => options.gear_size || "default",
               "Scaling:" => options.scaling ? "yes" : "no",
              }
             ).each { |s| say "  #{s}" }
      end

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
        add_issue("Jenkins failed to install - #{e}",
                  "Installing jenkins and jenkins-client",
                  "rhc app create jenkins",
                  "rhc cartridge add jenkins-client -a #{rest_app.name}")
      end

      # add jenkins-client cart
      begin
        setup_jenkins_client(rest_app) if jenkins_rest_app
      rescue Exception => e
        add_issue("Jenkins client failed to install - #{e}",
                  "Install the jenkins client",
                  "rhc cartridge add jenkins-client -a #{rest_app.name}")
      end

      if options.dns
        unless dns_propagated? rest_app.host
          add_issue("We were unable to lookup your hostname (#{rest_app.host}) in a reasonable amount of time and can not clone your application.",
                    "Clone your git repo",
                    "rhc app clone #{rest_app.name}")

          output_issues(rest_app)
          return 0
        end

        if options.git
          begin
            run_git_clone(rest_app)
          rescue RHC::GitException => e
            warn "#{e}"
            unless RHC::Helpers.windows? and windows_nslookup_bug?(rest_app)
              add_issue("We were unable to clone your application's git repo - #{e}",
                        "Clone your git repo",
                        "rhc app clone #{rest_app.name}")
            end
          end
        end
      end

      if issues?
        output_issues(rest_app)
      else
        results { rest_app.messages.each { |msg| say msg } }
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
      0
    end

    summary "Delete an application from the server"
    description "Deletes your application and all of its data from the server.",
                "Use with caution as this operation is permanent."
    syntax "<app> [--namespace namespace]"
    option ["-n", "--namespace namespace"], "Namespace to add your application to", :context => :namespace_context, :required => true
    argument :app, "The application you wish to delete", ["-a", "--app name"]
    alias_action :destroy, :deprecated => true
    def delete(app)
      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(app)

      do_delete = agree "Are you sure you wish to delete the '#{rest_app.name}' application? (yes/no)"
      if do_delete
        paragraph { say "Deleting application '#{rest_app.name}'" }
        rest_app.destroy
        results { say "Application '#{rest_app.name}' successfully deleted" }
      end
      0
    end

    summary "Start the application"
    syntax "<app> [--namespace namespace] [--app app]"
    argument :app, "The name of the application you are stopping", ["-a", "--app app"], :context => :app_context
    option ["-n", "--namespace namespace"], "Namespace of the application the cartrdige belongs to", :context => :namespace_context, :required => true
    def start(app)
      app_action app, :start

      results { say "#{app} started" }
      0
    end

    summary "Stop the application"
    syntax "<app> [--namespace namespace] [--app app]"
    argument :app, "The name of the application you are stopping", ["-a", "--app app"], :context => :app_context
    option ["-n", "--namespace namespace"], "Namespace of the application the cartrdige belongs to", :context => :namespace_context, :required => true
    def stop(app)
      app_action app, :stop

      results { say "#{app} stopped" }
      0
    end

    summary "Stops all application processes"
    syntax "<app> [--namespace namespace] [--app app]"
    argument :app, "The name of the application you are stopping", ["-a", "--app app"], :context => :app_context
    option ["-n", "--namespace namespace"], "Namespace of the application the cartrdige belongs to", :context => :namespace_context, :required => true
    def force_stop(app)
      app_action app, :stop, true

      results { say "#{app} force stopped" }
      0
    end

    summary "Restart the application"
    syntax "<app> [--namespace namespace] [--app app]"
    argument :app, "The name of the application you are stopping", ["-a", "--app app"], :context => :app_context
    option ["-n", "--namespace namespace"], "Namespace of the application the cartrdige belongs to", :context => :namespace_context, :required => true
    def restart(app)
      app_action app, :restart

      results { say "#{app} restarted" }
      0
    end

    summary "Reload the application's configuration"
    syntax "<app> [--namespace namespace] [--app app]"
    argument :app, "The name of the application you are stopping", ["-a", "--app app"], :context => :app_context
    option ["-n", "--namespace namespace"], "Namespace of the application the cartrdige belongs to", :context => :namespace_context, :required => true
    def reload(app)
      app_action app, :reload

      results { say "#{app} config reloaded" }
      0
    end

    summary "Clean out the application's logs and tmp directories and tidy up the git repo on the server"
    syntax "<app> [--namespace namespace] [--app app]"
    argument :app, "he name of the application you are stopping", ["-a", "--app app"], :context => :app_context
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    def tidy(app)
      app_action app, :tidy

      results { say "#{app} cleaned up" }
      0
    end

    summary "Show information about an application"
    syntax "<app> [--namespace namespace] [--app app]"
    argument :app, "The name of the application you are getting information on", ["-a", "--app app"], :context => :app_context
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["--apache"], "Get the current status of the application"
    def show(app)
      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(app)
      unless options.apache
        say_app_info(rest_app)
      else
        rest_app.gear_groups.each do |gg|
          say gg.gears.first['state']
        end
      end
      0
    end

    summary "Show status of an application's gears"
    syntax "<app> [--namespace namespace] [--app app]"
    argument :app, "The name of the application you are getting information on", ["-a", "--app app"], :context => :app_context
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    def status(app)
      # TODO: add a way to deprecate this and alias to show --apache
      options.apache = true
      show(app)
    end

    private
      include RHC::GitHelpers
      include RHC::CartridgeHelpers

      def app_action(app, action, *args)
        rest_domain = rest_client.find_domain(options.namespace)
        rest_app = rest_domain.find_application(app)
        result = rest_app.send action, *args
        result
      end

      def create_app(name, cartridge, rest_domain, gear_size=nil, scale=nil)
        app_options = {:cartridge => cartridge}
        app_options[:gear_profile] = gear_size if gear_size
        app_options[:scale] = scale if scale
        app_options[:debug] = true if @debug

        debug "Creating application '#{name}' with these options - #{app_options}.inspect"

        rest_cartridge = find_cartridge rest_client, cartridge, "standalone"
        app_options[:cartridge] = rest_cartridge.name

        rest_app = rest_domain.add_application name, app_options

        debug "'#{rest_app.name}' created"

        rest_app
      end

      def dns_propagated?(host)
        #
        # Confirm that the host exists in DNS
        #
        say "Your application's domain name is being propagated worldwide (this might take a minute)..."
        debug "Start checking for application dns @ '#{host}'"

        found = false

        # Allow DNS to propagate
        Kernel.sleep 5

        # Now start checking for DNS
        sleep_time = 2
        for i in 0..MAX_RETRIES-1
          found = host_exist?(host)
          break if found

          say "    retry # #{i+1} - Waiting for DNS: #{host}"
          Kernel.sleep sleep_time.to_i
          sleep_time *= DEFAULT_DELAY_THROTTLE
        end

        debug "End checking for application dns @ '#{host} - found=#{found}'"

        found
      end

      def host_exist?(host)
        # :nocov:
        dns = Resolv::DNS.new
        dns.getresources(host, Resolv::DNS::Resource::IN::A).any?
        # :nocov:
      end

      def check_sshkeys!
        wizard = RHC::SSHWizard.new(rest_client)
        wizard.run
      end

      def run_git_clone(rest_app)
        debug "Pulling new repo down"

        check_sshkeys! unless options.noprompt

        repo_dir = options.repo || rest_app.name
        git_clone_repo rest_app.git_url, repo_dir

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
        return options.enable_jenkins if options.enable_jenkins.is_a?(String)
        nil
      end

      def check_jenkins(app_name, rest_domain)
        debug "Checking if jenkins arguments are valid"
        raise ArgumentError, "The --no-dns option can't be used in conjunction with --enable-jenkins when creating an application.  Either remove the --no-dns option or first install your application with --no-dns and then use 'rhc cartridge add' to embed the Jenkins client." unless options.dns


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

      def run_nslookup
        # :nocov:
        `nslookup #{rest_app.host}`
        $?.exitstatus == 0
        # :nocov:
      end

      def run_ping
        # :nocov:
        `ping #{rest_app.host}-n 2`
        $?.exitstatus == 0
        # :nocov:
      end

      def windows_nslookup_bug?(rest_app)
        windows_nslookup = run_nslookup
        windows_ping = run_ping

        if windows_nslookup and !windows_ping # this is related to BZ #826769
          issue = <<WINSOCKISSUE
We were unable to lookup your hostname (#{rest_app.host})
in a reasonable amount of time.  This can happen periodically and may
take up to 10 extra minutes to propagate depending on where you are in the
world. This may also be related to an issue with Winsock on Windows [1][2].
We recommend you wait a few minutes then clone your git repository manually.

[1] http://support.microsoft.com/kb/299357
[2] http://support.microsoft.com/kb/811259
WINSOCKISSUE
          add_issue(issue,
                    "Clone your git repo",
                    "rhc app clone #{rest_app.name}")

          return true
        end

        false
      end

      def output_issues(rest_app)
        reasons, steps = format_issues(4)
        warn <<WARNING_OUTPUT
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
WARNING:  Your application was created successfully but had problems during
          configuration. Below is a list of the issues and steps you can
          take to complete the configuration of your application.

  Application URL: #{rest_app.app_url}

  Issues:
#{reasons}
  Steps to complete your configuration:
#{steps}
  If you can't get your application '#{rest_app.name}' running in the browser,
  you can try destroying and recreating the application:

    $ rhc app destroy #{rest_app.name} --confirm

  If this doesn't work for you, let us know in the forums or in IRC and we'll
  make sure to get you up and running.

    Forums - https://openshift.redhat.com/community/forums/openshift
    IRC - #openshift (on Freenode)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

WARNING_OUTPUT
      end
  end
end
