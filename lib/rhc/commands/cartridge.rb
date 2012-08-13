require 'rhc/commands/base'

module RHC::Commands
  class Cartridge < Base
    summary "Manage your application cartridges"
    syntax "<action>"
    alias_action :"app cartridge", :root_command => true
    default_action :list

    summary "List supported embedded cartridges"
    def list
      carts = rest_client.cartridges.collect { |c| c.name }
      paragraph do
        say "RESULT:"
        say "  #{carts.join(', ')}"
      end
    end

    summary "Add a cartridge to your application"
    syntax "[<app>] <cartridge_type> [--timeout timeout]"
    argument :namespace, "Optional namespace of the application you are adding the cartrdige to", ["-n", "--namespace namespace"], :context => :namespace_context
    argument :app, "Application you are adding the cartride to", ["-a", "--app app"], :context => :app_context
    argument :cart_type, "The type of the cartridge you are adding (run 'rhc cartridge list' to obtain a list of available cartridges)", ["-c", "--cartridge cart_type"]
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :"app cartridge add", :root_command => true
    def add(namespace, app, cart_type)
      carts = rest_client.find_cartridges :regex => cart_regex(cart_type)

      if carts.length == 0
        paragraph do
          say "RESULT:"
          carts = rest_client.cartridges.collect { |c| c.name }
          say "Invalid type specified: '#{cart_type}'. Valid cartridge types are (#{carts.join(', ')})."
        end
        return 154
      end

      if carts.length > 1
        paragraph do
          say "RESULT:"
          say "Multiple cartridge versions match your criteria. Please specify one."
          carts.each { |cart| say "  #{cart.name}" }
        end
        return 155
      end

      cart = carts[0] if carts.length
      paragraph { say "Adding '#{cart.name}' to application '#{app}'" }
      paragraph do
        say "RESULT:"
        rest_domain = rest_client.find_domain(namespace)
        rest_app = rest_domain.find_application(app)
        rest_app.add_cartridge(cart.name)
        say "  Success!"
      end

      0
    end

    private

    def cart_regex(cart)
      "^#{cart.rstrip}(-[0-9\.]+){0,1}$"
    end
  end
end
