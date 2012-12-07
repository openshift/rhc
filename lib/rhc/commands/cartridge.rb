require 'rhc/commands/base'
require 'rhc/cartridge_helpers'

module RHC::Commands
  class Cartridge < Base
    summary "Manage your application cartridges"
    syntax "<action>"
    alias_action :"app cartridge", :root_command => true, :deprecated => true
    default_action :list

    summary "List supported embedded cartridges"
    alias_action :"app cartridge list", :root_command => true, :deprecated => true
    def list
      rest_client = RHC::Rest::Client.new(openshift_rest_node, nil, nil)
      list = rest_client.cartridges.
        map{ |c| [c.name, c.display_name || '', c.type == 'standalone' ? 'Y' : ''] }.
        sort do |a,b|
          if a[2] == 'Y' && b[2] == ''
            -1
          elsif a[2] == '' && b[2] == 'Y'
            1
          else
            a[1].downcase <=> b[1].downcase
          end
        end
      list.unshift ['==========', '=========', '=============']
      list.unshift ['Short Name', 'Full name', 'New apps only']

      paragraph{ say "Use the short name of a cartridge when interacting with your applications." }

      say table(list).join("\n")

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

      display_cart(rest_cartridge,rest_cartridge.properties[:cart_data])

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

    summary 'View/manipulate storage on a cartridge'
    syntax '<cartridge> -a app [--show] [--add|--remove|--set amount] [--namespace namespace] [--timeout timeout]'
    argument :cart_type, "The name of the cartridge", ["-c", "--cartridge cart_type"], :arg_type => :list
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    option ["--show"], "Show the current base and additional storage capacity"
    option ["--add amount"], "Add the indicated amount to the additional storage capacity"
    option ["--remove amount"], "Remove the indicated amount from the additional storage capacity"
    option ["--set amount"], "Set the specified amount of additional storage capacity"
    option ["-f", "--force"], "Force the action"
    def storage(cartridges)
      # Make sure that we are dealing with an array (-c param will only pass in a string)
      # BZ 883658
      cartridges = [cartridges].flatten

      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(options.app)

      # Pull the desired action
      #
      actions = options.__hash__.keys & [:show, :add, :remove, :set]

      # Ensure that only zero or one action was selected
      raise RHC::AdditionalStorageArgumentsException if actions.length > 1

      operation = actions.first || :show
      amount = options.__hash__[operation]

      # Perform a storage change action if requested
      if operation == :show
        results do
          if cartridges.length == 0
            display_cart_storage_list rest_app.cartridges
          else
            cartridges.each do |cartridge_name|
              cart = rest_app.find_cartridge(cartridge_name)
              display_cart_storage_info cart, cart.display_name
            end
          end
        end
      else
        raise RHC::MultipleCartridgesException,
          'Exactly one cartridge must be specified for this operation' if cartridges.length != 1

        rest_cartridge = find_cartridge rest_app, cartridges.first, nil
        amount = amount.match(/^(\d+)(GB)?$/i)
        raise RHC::AdditionalStorageValueException if amount.nil?

        # If the amount is specified, find the regex match and convert to a number
        amount = amount[1].to_i
        total_amount = rest_cartridge.additional_gear_storage

        if operation == :add
          total_amount += amount
        elsif operation == :remove
          if amount > total_amount && !options.force
            raise RHC::AdditionalStorageRemoveException
          else
            total_amount = [total_amount - amount, 0].max
          end
        else
          total_amount = amount
        end

        cart = rest_cartridge.set_storage(:additional_gear_storage => total_amount)
        results do
          say "Success: additional storage space set to #{total_amount}GB\n"
          display_cart_storage_info cart
        end
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
