require 'rhc/commands/base'

module RHC::Commands
  class Cartridge < Base
    summary "Manage your application cartridges"
    syntax "<action>"
    alias_action :"app cartridge", :root_command => true
    default_action :list

    summary "List supported embedded cartridges"
    alias_action :"app cartridge list", :root_command => true
    def list
      carts = rest_client.cartridges.collect { |c| c.name }
      results { say "#{carts.join(', ')}" }
      0
    end

    summary "Add a cartridge to your application"
    syntax "<cartridge_type> [--timeout timeout] [--namespace namespace] [--app app]"
    argument :cart_type, "The type of the cartridge you are adding (run 'rhc cartridge list' to obtain a list of available cartridges)", ["-c", "--cartridge cart_type"]
    option ["-n", "--namespace namespace"], "Namespace of the application you are adding the cartrdige to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you are adding the cartride to", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :"app cartridge add", :root_command => true
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

    private

      def cart_regex(cart)
        "^#{cart.rstrip}(-[0-9\.]+){0,1}$"
      end
  end
end
