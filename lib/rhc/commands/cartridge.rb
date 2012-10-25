require 'rhc/commands/base'
require 'rhc/cartridge_helper'

module RHC::Commands
  class Cartridge < Base
    summary "Manage your application cartridges"
    syntax "<action>"
    alias_action :"app cartridge", :root_command => true, :deprecated => true
    default_action :list

    summary "List supported embedded cartridges"
    alias_action :"app cartridge list", :root_command => true, :deprecated => true
    def list
      carts = rest_client.find_cartridges(:type => 'embedded').collect { |c| c.name }
      results { say "#{carts.join(', ')}" }
      0
    end

    summary "Add a cartridge to your application"
    syntax "<cartridge_type> [--namespace namespace] [--app app]"
    option ["-n", "--namespace namespace"], "Namespace of the application you are adding the cartridge to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you are adding the cartridge to", :context => :app_context, :required => true
    argument :cart_type, "The type of the cartridge you are adding (run 'rhc cartridge list' to obtain a list of available cartridges)", ["-c", "--cartridge cart_type"]
    alias_action :"app cartridge add", :root_command => true, :deprecated => true
    def add(cart_type)
      cart = find_cartridge rest_client, cart_type

      say "Adding '#{cart.name}' to application '#{options.app}'"

      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(options.app)
      rest_cartridge = rest_app.add_cartridge(cart.name)
      say "Success"

      display_cart(rest_cartridge)

      0
    end

    summary "Show useful information about a cartridge"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    option ["-n", "--namespace namespace"], "Namespace of the application you are adding the cartridge to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you are adding the cartridge to", :context => :app_context, :required => true
    argument :cartridge, "The name of the cartridge", ["-c", "--cartridge cart_type"]
    def show(cartridge)
      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(options.app)
      rest_cartridge = find_cartridge rest_app, cartridge, nil

      display_cart(rest_cartridge,rest_cartridge.properties[:cart_data])

      0
    end

    summary "Remove a cartridge from your application"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    argument :cartridge, "The name of the cartridge you are removing", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application you are removing the cartridge from", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you are removing the cartridge from", :context => :app_context, :required => true
    option ["--confirm"], "Safety switch - if this switch is not passed a warning is printed out and the cartridge will not be removed"
    alias_action :"app cartridge remove", :root_command => true, :deprecated => true
    def remove(cartridge)
      unless options.confirm
        results { say "Removing a cartridge is a destructive operation that may result in loss of data associated with the cartridge.  You must pass the --confirm switch to this command in order to to remove the cartridge." }
        return 1
      end

      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(options.app)
      rest_cartridge = rest_app.find_cartridge cartridge, :type => "embedded"
      rest_cartridge.destroy

      results { say "Success: Cartridge '#{rest_cartridge.name}' removed from application '#{rest_app.name}'." }
      0
    end

    summary "Start a cartridge"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are stopping", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartrdige belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge", :context => :app_context, :required => true
    alias_action :"app cartridge start", :root_command => true, :deprecated => true
    def start(cartridge)
      cartridge_action cartridge, :start

      results { say "#{cartridge} started!" }
      0
    end

    summary "Stop a cartridge"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are stopping", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge stop", :root_command => true, :deprecated => true
    def stop(cartridge)
      cartridge_action cartridge, :stop

      results { say "#{cartridge} stopped!" }
      0
    end

    summary "Restart a cartridge"
    syntax "<cartridge_type> [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are restarting", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge restart", :root_command => true, :deprecated => true
    def restart(cartridge)
      cartridge_action cartridge, :restart

      results { say "#{cartridge} restarted!" }
      0
    end

    summary "Get current the status of a cartridge"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are getting the status of", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge status", :root_command => true, :deprecated => true
    def status(cartridge)
      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(options.app)
      rest_cartridge = find_cartridge(rest_app, cartridge)
      msgs = rest_cartridge.status
      results {
        msgs.each do |msg|
          say msg['message']
        end
      }
      0
    end

    summary "Reload the cartridge's configuration"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are reloading", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge reload", :root_command => true, :deprecated => true
    def reload(cartridge)
      cartridge_action cartridge, :reload

      results { say "#{cartridge} config reloaded!" }
      0
    end

    summary "Set the scaling range of a cartridge"
    syntax "<cartridge> [--timeout timeout] [--namespace namespace] [--app app] [--min min] [--max max]"
    argument :cart_type, "The name of the cartridge you are reloading", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    option ["--min min", Integer], "Minimum scaling value"
    option ["--max max", Integer], "Maximum scaling value"
    def scale(cartridge)
      raise RHC::MissingScalingValueException unless options.min || options.max

      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(options.app)
      rest_cartridge = find_cartridge rest_app, cartridge, nil

      raise RHC::CartridgeNotScalableException unless rest_cartridge.scalable?

      cart = rest_cartridge.set_scales({
        :scales_from => options.min,
        :scales_to   => options.max
      })

      results do
        say "Success: Scaling values updated"
        display_cart(cart)
      end

      0
    end

    private
    include RHC::CartridgeHelpers

    def cartridge_action(cartridge, action)
      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(options.app)
      rest_cartridge = find_cartridge rest_app, cartridge
      result = rest_cartridge.send action
      [result, rest_cartridge, rest_app, rest_domain]
    end
  end
end
