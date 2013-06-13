require 'rhc/commands/base'
require 'resolv'
require 'rhc/git_helpers'
require 'rhc/cartridge_helpers'

module RHC::Commands
  class App < Base
    summary "Commands for creating and managing applications"
    description <<-DESC
      Creates and controls an OpenShift application.  To see the list of all 
      applications use the rhc domain show command.  Note that delete is not 
      reversible and will stop your application and then remove the application 
      and repo from the remote server. No local changes are made.
      DESC
    syntax "<action>"
    default_action :help
    suppress_wizard

    summary "Create an application"
    description <<-DESC
      Create an application. Every OpenShift application must have one
      web cartridge which serves web requests, and can have a number of
      other cartridges which provide capabilities like databases,
      scheduled jobs, or continuous integration.

      You can see a list of all valid cartridge types by running
      'rhc cartridge list'. OpenShift also supports downloading cartridges -
      pass a URL in place of the cartridge name and we'll download 
      and install that cartridge into your app.  Keep in mind that
      these cartridges receive no security updates.  Note that not
      all OpenShift servers allow downloaded cartridges.

      When your application is created, a domain name that is a combination
      of the name of your app and the namespace of your domain will be
      registered in DNS.  A copy of the code for your application
      will be checked out locally into a folder with the same name as
      your application.  Note that different types of applications may
      require different structures - check the README provided with the
      cartridge if you have questions.

      OpenShift runs the components of your application on small virtual
      servers called "gears".  Each account or plan is limited to a number
      of gears which you can use across multiple applications.  Some
      accounts or plans provide access to gears with more memory or more
      CPU.  Run 'rhc account' to see the number and sizes of gears available
      to you.  When creating an application the --gear-size parameter
      may be specified to change the gears used.

      DESC
    syntax "<name> <cartridge> [... <cartridge>] [-n namespace]"
    option ["-n", "--namespace NAME"], "Namespace for the application"
    option ["-g", "--gear-size SIZE"], "Gear size controls how much memory and CPU your cartridges can use."
    option ["-s", "--scaling"], "Enable scaling for the web cartridge."
    option ["-r", "--repo DIR"], "Path to the Git repository (defaults to ./$app_name)"
    option ["--from-code URL"], "URL to a Git repository that will become the initial contents of the application"
    option ["--[no-]git"], "Skip creating the local Git repository."
    option ["--nogit"], "DEPRECATED: Skip creating the local Git repository.", :deprecated => {:key => :git, :value => false}
    option ["--[no-]dns"], "Skip waiting for the application DNS name to resolve. Must be used in combination with --no-git"
    option ['--no-keys'], "Skip checking SSH keys during app creation", :hide => true
    option ["--enable-jenkins [NAME]"], "Enable Jenkins builds for this application (will create a Jenkins application if not already available). The default name will be 'jenkins' if not specified."
    argument :name, "Name for your application", ["-a", "--app NAME"], :optional => true
    argument :cartridges, "The web framework this application should use", ["-t", "--type CARTRIDGE"], :optional => true, :arg_type => :list
    def create(name, cartridges)
      check_config!

      check_name!(name)

      cartridges = check_cartridges(cartridges, &require_one_web_cart)

      options.default \
        :dns => true,
        :git => true

      raise ArgumentError, "You have named both your main application and your Jenkins application '#{name}'. In order to continue you'll need to specify a different name with --enable-jenkins or choose a different application name." if jenkins_app_name == name && enable_jenkins?

      rest_domain = check_domain!
      rest_app = nil
      repo_dir = nil

      cart_names = cartridges.collect do |c|
        c.usage_rate? ? "#{c.short_name} (addtl. costs may apply)" : c.short_name
      end.join(', ')

      paragraph do
        header "Application Options"
        table([["Namespace:", options.namespace],
               ["Cartridges:", cart_names],
              (["Source Code:", options.from_code] if options.from_code),
               ["Gear Size:", options.gear_size || "default"],
               ["Scaling:", options.scaling ? "yes" : "no"],
              ].compact
             ).each { |s| say "  #{s}" }
      end

      paragraph do
        say "Creating application '#{name}' ... "

        # create the main app
        rest_app = create_app(name, cartridges, rest_domain, options.gear_size, options.scaling, options.from_code)
        success "done"

        paragraph{ indent{ success rest_app.messages.map(&:strip) } }
      end

      build_app_exists = rest_app.building_app

      if enable_jenkins?
        unless build_app_exists
          paragraph do
            say "Setting up a Jenkins application ... "

            begin
              build_app_exists = add_jenkins_app(rest_domain)

              success "done"
              paragraph{ indent{ success build_app_exists.messages.map(&:strip) } }

            rescue Exception => e
              warn "not complete"
              add_issue("Jenkins failed to install - #{e}",
                        "Installing jenkins and jenkins-client",
                        "rhc create-app jenkins",
                        "rhc add-cartridge jenkins-client -a #{rest_app.name}")
            end
          end
        end

        paragraph do
          messages = []
          add_jenkins_client_to(rest_app, messages)
          paragraph{ indent{ success messages.map(&:strip) } }
        end if build_app_exists
      end

      debug "Checking SSH keys through the wizard"
      check_sshkeys! unless options.no_keys

      if options.dns
        paragraph do
          say "Waiting for your DNS name to be available ... "
          if dns_propagated? rest_app.host
            success "done"
          else
            warn "failure"
            add_issue("We were unable to lookup your hostname (#{rest_app.host}) in a reasonable amount of time and can not clone your application.",
                      "Clone your git repo",
                      "rhc git-clone #{rest_app.name}")

            output_issues(rest_app)
            return 0
          end
        end

        if options.git
          section(:now => true, :top => 1, :bottom => 1) do
            begin
              repo_dir = git_clone_application(rest_app)
            rescue RHC::GitException => e
              warn "#{e}"
              unless RHC::Helpers.windows? and windows_nslookup_bug?(rest_app)
                add_issue("We were unable to clone your application's git repo - #{e}",
                          "Clone your git repo",
                          "rhc git-clone #{rest_app.name}")
              end
            end
          end
        end
      end

      output_issues(rest_app) if issues?
            
      paragraph do
        say "Your application '#{rest_app.name}' is now available."
        paragraph do
          indent do
            say table [
                ['URL:', rest_app.app_url],
                ['SSH to:', rest_app.ssh_string],
                ['Git remote:', rest_app.git_url],
                (['Cloned to:', repo_dir] if repo_dir)
              ].compact
          end
        end
      end
      paragraph{ say "Run 'rhc show-app #{name}' for more details about your app." }

      0
    end


    summary "Delete an application from the server"
    description "Deletes your application and all of its data from the server.",
                "Use with caution as this operation is permanent."
    syntax "<app> [--namespace NAME]"
    option ["-n", "--namespace NAME"], "Namespace your application belongs to", :context => :namespace_context, :required => true
    option ["-b", "--bypass"], "DEPRECATED Please use '--confirm'", :deprecated => {:key => :confirm, :value => true}
    option ["--confirm"], "Pass to confirm deleting the application"
    argument :app, "The application you wish to delete", ["-a", "--app name"], :context => :app_context
    alias_action :destroy, :deprecated => true
    def delete(app)
      rest_app = rest_client.find_application(options.namespace, app)

      confirm_action "#{color("This is a non-reversible action! Your application code and data will be permanently deleted if you continue!", :yellow)}\n\nAre you sure you want to delete the application '#{app}'?"

      say "Deleting application '#{rest_app.name}' ... "
      rest_app.destroy
      success "deleted"

      0
    end

    summary "Start the application"
    syntax "<app> [--namespace NAME] [--app NAME]"
    argument :app, "The name of the application you are starting", ["-a", "--app NAME"], :context => :app_context
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    def start(app)
      app_action app, :start

      results { say "#{app} started" }
      0
    end

    summary "Stop the application"
    syntax "<app> [--namespace NAME] [--app NAME]"
    argument :app, "The name of the application you are stopping", ["-a", "--app NAME"], :context => :app_context
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    def stop(app)
      app_action app, :stop

      results { say "#{app} stopped" }
      0
    end

    summary "Stops all application processes"
    syntax "<app> [--namespace NAME] [--app NAME]"
    argument :app, "The name of the application you are stopping", ["-a", "--app NAME"], :context => :app_context
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    def force_stop(app)
      app_action app, :stop, true

      results { say "#{app} force stopped" }
      0
    end

    summary "Restart the application"
    syntax "<app> [--namespace NAME] [--app NAME]"
    argument :app, "The name of the application you are restarting", ["-a", "--app NAME"], :context => :app_context
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    def restart(app)
      app_action app, :restart

      results { say "#{app} restarted" }
      0
    end

    summary "Reload the application's configuration"
    syntax "<app> [--namespace NAME] [--app NAME]"
    argument :app, "The name of the application you are reloading", ["-a", "--app NAME"], :context => :app_context
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    def reload(app)
      app_action app, :reload

      results { say "#{app} config reloaded" }
      0
    end

    summary "Clean out the application's logs and tmp directories and tidy up the git repo on the server"
    syntax "<app> [--namespace NAME] [--app NAME]"
    argument :app, "The name of the application you are tidying", ["-a", "--app NAME"], :context => :app_context
    option ["-n", "--namespace NAME"], "Namespace of the application belongs to", :context => :namespace_context, :required => true
    def tidy(app)
      app_action app, :tidy

      results { say "#{app} cleaned up" }
      0
    end

    summary "Show information about an application"
    syntax "<app> [--namespace NAME]"
    argument :app, "The name of the application you are getting information on", ["-a", "--app NAME"], :context => :app_context
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["--state"], "Get the current state of the cartridges in this application"
    option ["--gears"], "Show the ID, state, and cartridges on each gear in this application"
    def show(app_name)

      if options.state
        gear_groups_for_app(app_name).each do |gg|
          say "Cartridge #{gg.cartridges.collect { |c| c['name'] }.join(', ')} is #{gear_group_state(gg.gears.map{ |g| g['state'] })}"
        end
      elsif options.gears
        gear_info = gear_groups_for_app(app_name).map do |group|
          group.gears.map do |gear|
            [
              gear['id'],
              gear['state'] == 'started' ? gear['state'] : color(gear['state'], :yellow),
              group.cartridges.collect{ |c| c['name'] }.join(' '),
              group.gear_profile,
              ssh_string(gear['ssh_url'])
            ]
          end
        end.flatten(1)

        say table(gear_info, :header => ['ID', 'State', 'Cartridges', 'Size', 'SSH URL'])
      else
        app = rest_client.find_application(options.namespace, app_name, :include => :cartridges)
        display_app(app, app.cartridges)
      end

      0
    end

    summary "SSH into the specified application"
    syntax "<app> [--ssh path_to_ssh_executable]"
    argument :app, "The name of the application you want to SSH into", ["-a", "--app NAME"], :context => :app_context
    option ["--ssh PATH"], "Path to your SSH executable"
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    alias_action 'ssh', :root_command => true
    def ssh(app_name)
      raise ArgumentError, "No application specified" unless app_name.present?
      raise OptionParser::InvalidOption, "No system SSH available. Please use the --ssh option to specify the path to your SSH executable, or install SSH." unless options.ssh or has_ssh?

      rest_app = rest_client.find_application(options.namespace, app_name)

      say "Connecting to #{rest_app.ssh_string.to_s} ..."
      if options.ssh
        debug "Using user specified SSH: #{options.ssh}"
        Kernel.send(:system, "#{options.ssh} #{rest_app.ssh_string.to_s}")
      else
        debug "Using system ssh"
        Kernel.send(:system, "ssh #{rest_app.ssh_string.to_s}")
      end
    end

    summary "DEPRECATED use 'show <app> --state' instead"
    syntax "<app> [--namespace NAME] [--app NAME]"
    argument :app, "The name of the application you are getting information on", ["-a", "--app NAME"], :context => :app_context
    option ["-n", "--namespace NAME"], "Namespace of the application belongs to", :context => :namespace_context, :required => true
    deprecated "rhc app show --state"
    def status(app)
      # TODO: add a way to deprecate this and alias to show --apache
      options.state = true
      show(app)
    end

    private
      include RHC::GitHelpers
      include RHC::CartridgeHelpers

      def require_one_web_cart
        lambda{ |carts|
          match, ambiguous = carts.partition{ |c| not c.is_a?(Array) }
          selected_web = match.any?{ |c| not c.only_in_existing? }
          possible_web = ambiguous.flatten.any?{ |c| not c.only_in_existing? }
          if not (selected_web or possible_web)
            section(:bottom => 1){ list_cartridges(standalone_cartridges) }
            raise RHC::CartridgeNotFoundException, "Every application needs a web cartridge to handle incoming web requests. Please provide the short name of one of the carts listed above."
          end
          if selected_web
            carts.map! &other_carts_only
          elsif possible_web
            carts.map! &web_carts_only
          end
        }
      end

      def check_sshkeys!
        return unless interactive?
        RHC::SSHWizard.new(rest_client, config, options).run
      end

      def check_name!(name)
        return unless name.blank?

        paragraph{ say "When creating an application, you must provide a name and a cartridge from the list below:" }
        paragraph{ list_cartridges(standalone_cartridges) }

        raise ArgumentError, "Please specify the name of the application and the web cartridge to install"
      end

      def check_config!
        return if not interactive? or (!options.clean && config.has_local_config?) or (options.server && (options.rhlogin || options.token))
        RHC::EmbeddedWizard.new(config, options).run
      end

      def check_domain!
        if options.namespace
          rest_client.find_domain(options.namespace)
        else
          if rest_client.domains.empty?
            raise RHC::Rest::DomainNotFoundException, "No domains found. Please create a domain with 'rhc create-domain <namespace>' before creating applications." unless interactive?
            RHC::DomainWizard.new(config, options, rest_client).run
          end
          domain = rest_client.domains.first
          raise RHC::Rest::DomainNotFoundException, "No domains found. Please create a domain with 'rhc create-domain <namespace>' before creating applications." unless domain
          options.namespace = domain.id
          domain
        end
      end


      def gear_groups_for_app(app_name)
        rest_client.find_application_gear_groups(options.namespace, app_name)
      end

      def gear_group_state(states)
        return states[0] if states.length == 1 || states.uniq.length == 1
        "#{states.select{ |s| s == 'started' }.count}/#{states.length} started"
      end

      def app_action(app, action, *args)
        rest_app = rest_client.find_application(options.namespace, app)
        result = rest_app.send action, *args
        result
      end

      def create_app(name, cartridges, rest_domain, gear_size=nil, scale=nil, from_code=nil)
        app_options = {:cartridges => Array(cartridges)}
        app_options[:gear_profile] = gear_size if gear_size
        app_options[:scale] = scale if scale
        app_options[:initial_git_url] = from_code if from_code
        app_options[:debug] = true if @debug
        debug "Creating application '#{name}' with these options - #{app_options.inspect}"
        rest_app = rest_domain.add_application(name, app_options)
        debug "'#{rest_app.name}' created"

        rest_app
      rescue RHC::Rest::Exception => e
        if e.code == 109
          paragraph{ say "Valid cartridge types:" }
          paragraph{ list_cartridges(standalone_cartridges) }
        end
        raise
      end

      def add_jenkins_app(rest_domain)
        create_app(jenkins_app_name, "jenkins-1.4", rest_domain)
      end

      def add_jenkins_cartridge(rest_app)
        rest_app.add_cartridge("jenkins-client-1.4")
      end

      def add_jenkins_client_to(rest_app, messages)
        say "Setting up Jenkins build ... "
        successful, attempts, exit_code, exit_message = false, 1, 157, nil
        while (!successful && exit_code == 157 && attempts < MAX_RETRIES)
          begin
            cartridge = add_jenkins_cartridge(rest_app)
            successful = true

            success "done"
            messages.concat(cartridge.messages)

          rescue RHC::Rest::ServerErrorException => e
            if (e.code == 157)
              # error downloading Jenkins /jnlpJars/jenkins-cli.jar
              attempts += 1
              debug "Jenkins server could not be contacted, sleep and then retry: attempt #{attempts}\n    #{e.message}"
              Kernel.sleep(10)
            end
            exit_code = e.code
            exit_message = e.message
          rescue Exception => e
            # timeout and other exceptions
            exit_code = 1
            exit_message = e.message
          end
        end
        unless successful
          warn "not complete"
          add_issue("Jenkins client failed to install - #{exit_message}",
                    "Install the jenkins client",
                    "rhc add-cartridge jenkins-client -a #{rest_app.name}")
        end
      end

      def dns_propagated?(host, sleep_time=2)
        #
        # Confirm that the host exists in DNS
        #
        debug "Start checking for application dns @ '#{host}'"

        found = false

        # Allow DNS to propagate
        Kernel.sleep 5

        # Now start checking for DNS
        host_found = hosts_file_contains?(host) or
        1.upto(MAX_RETRIES) { |i|
          host_found = host_exists?(host)
          break found if host_found

          say "    retry # #{i} - Waiting for DNS: #{host}"
          Kernel.sleep sleep_time.to_i
          sleep_time *= DEFAULT_DELAY_THROTTLE
        }

        debug "End checking for application dns @ '#{host} - found=#{found}'"

        host_found
      end

      def enable_jenkins?
        # legacy issue, commander 4.0.x will place the option in the hash with nil value (BZ878407)
        options.__hash__.has_key?(:enable_jenkins)
      end

      def jenkins_app_name
        if options.enable_jenkins.is_a? String
          options.enable_jenkins
        end || "jenkins"
      end

      def run_nslookup(host)
        # :nocov:
        `nslookup #{host}`
        $?.exitstatus == 0
        # :nocov:
      end

      def run_ping(host)
        # :nocov:
        `ping #{host} -n 2`
        $?.exitstatus == 0
        # :nocov:
      end

      # check the version of SSH that is installed
      def ssh_version
        @ssh_version ||= `ssh -V 2>&1`.strip
      end

      # return whether or not SSH is installed
      def has_ssh?
        @has_ssh ||= begin
          @ssh_version = nil
          ssh_version
          $?.success?
        rescue
          false
        end
      end

      def windows_nslookup_bug?(rest_app)
        windows_nslookup = run_nslookup(rest_app.host)
        windows_ping = run_ping(rest_app.host)

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
                    "rhc git-clone #{rest_app.name}")

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
  If you continue to experience problems after completing these steps,
  you can try destroying and recreating the application:

    $ rhc app delete #{rest_app.name} --confirm

  Please contact us if you are unable to successfully create your 
  application:

    Support - https://www.openshift.com/support

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

WARNING_OUTPUT
      end

    # Issues collector collects a set of recoverable issues and steps to fix them
    # for output at the end of a complex command
    def add_issue(reason, commands_header, *commands)
      @issues ||= []
      issue = {:reason => reason,
               :commands_header => commands_header,
               :commands => commands}
      @issues << issue
    end

    def format_issues(indent)
      return nil unless issues?

      indentation = " " * indent
      reasons = ""
      steps = ""

      @issues.each_with_index do |issue, i|
        reasons << "#{indentation}#{i+1}. #{issue[:reason].strip}\n"
        steps << "#{indentation}#{i+1}. #{issue[:commands_header].strip}\n"
        issue[:commands].each { |cmd| steps << "#{indentation}  $ #{cmd}\n" }
      end

      [reasons, steps]
    end

    def issues?
      not @issues.nil?
    end      
  end
end
