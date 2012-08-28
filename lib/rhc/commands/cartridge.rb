require 'rhc/commands/base'

module RHC::Commands
  class Cartridge < Base
    summary "Manage your application cartridges"
    syntax "<action>"
    alias_action :"app cartridge", :root_command => true
    default_action :list

    summary "List supported embedded cartridges"
    alias_action :"app cartridge list", :root_command => true, :deprecated => true
    def list
      carts = rest_client.cartridges.collect { |c| c.name }
      results { say "#{carts.join(', ')}" }
      0
    end

    summary "Add a cartridge to your application"
    syntax "<cartridge_type> [--timeout timeout] [--namespace namespace] [--app app]"
    argument :cart_type, "The type of the cartridge you are adding (run 'rhc cartridge list' to obtain a list of available cartridges)", ["-c", "--cartridge cart_type"]
    option ["-n", "--namespace namespace"], "Namespace of the application you are adding the cartridge to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you are adding the cartridge to", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :"app cartridge add", :root_command => true, :deprecated => true
    def add(cart_type)
      carts = rest_client.find_cartridges :regex => cart_regex(cart_type)
      app = options.app
      namespace = options.namespace

      if carts.length == 0
        carts = rest_client.cartridges.collect { |c| c.name }
        results do
          say "Invalid type specified: '#{cart_type}'. Valid cartridge types are (#{carts.join(', ')})."
        end
        return 154
      end

      if carts.length > 1
        results do
          say "Multiple cartridge versions match your criteria. Please specify one."
          carts.each { |cart| say "#{cart.name}" }
        end
        return 155
      end

      cart = carts[0] if carts.length
      paragraph { say "Adding '#{cart.name}' to application '#{app}'" }

      rest_domain = rest_client.find_domain(namespace)
      rest_app = rest_domain.find_application(app)
      rest_app.add_cartridge(cart.name)
      results { say "  Success!" }

      0
    end

    summary "Remove a cartridge from your application"
    syntax "<cartridge> [--timeout timeout] [--namespace namespace] [--app app]"
    argument :cartridge, "The name of the cartridge you are removing", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application you are removing the cartridge from", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you are removing the cartridge from", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    option ["--confirm"], "Safety switch - if this switch is not passed a warning is printed out and the cartridge will not be removed"
    alias_action :"app cartridge remove", :root_command => true, :deprecated => true
    def remove(cartridge)
      app = options.app
      namespace = options.namespace
      confirm = options.confirm

      unless confirm
        results { say "Removing a cartridge is a destructive operation that may result in loss of data associated with the cartridge.  You must pass the --confirm switch to this command in order to to remove the cartridge." }
        return 1
      end

      rest_domain = rest_client.find_domain(namespace)
      rest_app = rest_domain.find_application(app)
      rest_cartridge = rest_app.find_cartridge cartridge, :type => "embedded"

      rest_cartridge.destroy

      results { say "Success! Cartridge #{rest_cartridge.name} removed from application #{rest_app.name}." }
    end

    summary "Start a cartridge"
    syntax "<cartridge> [--timeout timeout] [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are stopping", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartrdige belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :"app cartridge start", :root_command => true, :deprecated => true
    def start(cartridge)
      app = options.app
      namespace = options.namespace

      rest_domain = rest_client.find_domain(namespace)
      rest_app = rest_domain.find_application(app)
      rest_cartridge = rest_app.find_cartridge cartridge, :type => "embedded"
      rest_cartridge.start

      results { say "#{cartridge} started!" }
      0
    end

    summary "Stop a cartridge"
    syntax "<cartridge> [--timeout timeout] [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are stopping", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you the cartridge belongs to", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :"app cartridge stop", :root_command => true, :deprecated => true
    def stop(cartridge)
      app = options.app
      namespace = options.namespace

      rest_domain = rest_client.find_domain(namespace)
      rest_app = rest_domain.find_application(app)
      rest_cartridge = rest_app.find_cartridge cartridge, :type => "embedded"
      rest_cartridge.stop

      results { say "#{cartridge} stopped!" }
      0
    end

    summary "Restart a cartridge"
    syntax "<cartridge_type> [--timeout timeout] [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are restarting", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :"app cartridge restart", :root_command => true, :deprecated => true
    def restart(cartridge)
      app = options.app
      namespace = options.namespace

      rest_domain = rest_client.find_domain(namespace)
      rest_app = rest_domain.find_application(app)
      rest_cartridge = rest_app.find_cartridge cartridge, :type => "embedded"
      rest_cartridge.restart

      results { say "#{cartridge} restarted!" }
      0
    end

    summary "Get current the status of a cartridge"
    syntax "<cartridge> [--timeout timeout] [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are getting the status of", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :"app cartridge status", :root_command => true, :deprecated => true
    def status(cartridge)
    end

    summary "Reload the cartridge's configuration"
    syntax "<cartridge> [--timeout timeout] [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are reloading", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :"app cartridge reload", :root_command => true, :deprecated => true
    def reload(cartridge)
      app = options.app
      namespace = options.namespace

      rest_domain = rest_client.find_domain(namespace)
      rest_app = rest_domain.find_application(app)
      rest_cartridge = rest_app.find_cartridge cartridge, :type => "embedded"
      rest_cartridge.reload

      results { say "#{cartridge} config reloaded!" }
      0
    end

    private

      def cart_regex(cart)
        "^#{cart.rstrip}(-[0-9\.]+){0,1}$"
      end
  end
end
