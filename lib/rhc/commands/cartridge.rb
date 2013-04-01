require 'rhc/commands/base'
require 'rhc/cartridge_helpers'

module RHC::Commands
  class Cartridge < Base
    summary "Manage your application cartridges"
    syntax "<action>"
    alias_action :"app cartridge", :root_command => true, :deprecated => true
    default_action :list

    summary "List available cartridges"
    option ["-v", "--verbose"], "Display more details about each cartridge"
    alias_action :"app cartridge list", :root_command => true, :deprecated => true
    alias_action :"cartridges", :root_command => true
    def list
      carts = rest_client.cartridges.sort_by{ |c| "#{c.type == 'standalone' && 1}_#{c.tags.include?('experimental') ? 1 : 0}_#{(c.display_name || c.name).downcase}" }

      if options.verbose
        carts.each do |c|
          paragraph do 
            name = c.display_name != c.name && "#{color(c.display_name, :cyan)} [#{c.name}]" || c.name
            tags = c.tags - RHC::Rest::Cartridge::HIDDEN_TAGS
            say header([name, "(#{c.only_in_new? ? 'web' : 'addon'})"])
            say c.description
            paragraph{ say "Tagged with: #{tags.sort.join(', ')}" } if tags.present?
            paragraph{ say format_usage_message(c) } if c.usage_rate?
          end
        end
      else
        say table(carts.collect do |c|
          [c.usage_rate? ? "#{c.name} (*)" : c.name,
           c.display_name,
           c.only_in_new? ? 'web' : 'addon']
        end)
      end

      paragraph{ say "Note: Web cartridges can only be added to new applications." }
      paragraph{ say "(*) denotes a cartridge with additional usage costs." } if carts.any? { |c| c.usage_rate? }

      0
    end

    summary "Add a cartridge to your application"
    syntax "<cartridge_type> [--namespace namespace] [--app app]"
    option ["-n", "--namespace namespace"], "Namespace of the application you are adding the cartridge to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you are adding the cartridge to", :context => :app_context, :required => true
    argument :cart_type, "The type of the cartridge you are adding (run 'rhc cartridge list' to obtain a list of available cartridges)", ["-c", "--cartridge cart_type"]
    alias_action :"app cartridge add", :root_command => true, :deprecated => true
    def add(cart_type)
      cart = check_cartridges(cart_type, :from => not_standalone_cartridges).first

      say "Adding #{cart.name} to application '#{options.app}' ... "

      say format_usage_message(cart) if cart.usage_rate?

      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      rest_cartridge = rest_app.add_cartridge(cart.name)

      success "Success"

      paragraph{ display_cart(rest_cartridge) }

      results{ rest_cartridge.messages.each { |msg| success msg } }

      0
    end

    summary "Show useful information about a cartridge"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    option ["-n", "--namespace namespace"], "Namespace of the application you are adding the cartridge to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you are adding the cartridge to", :context => :app_context, :required => true
    argument :cartridge, "The name of the cartridge", ["-c", "--cartridge cart_type"]
    def show(cartridge)
      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first

      display_cart(rest_cartridge)

      0
    end

    summary "Remove a cartridge from your application"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    argument :cartridge, "The name of the cartridge you are removing", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application you are removing the cartridge from", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you are removing the cartridge from", :context => :app_context, :required => true
    option ["--confirm"], "Pass to confirm removing the cartridge"
    alias_action :"app cartridge remove", :root_command => true, :deprecated => true
    def remove(cartridge)
      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first

      confirm_action "Removing a cartridge is a destructive operation that may result in loss of data associated with the cartridge.\n\nAre you sure you wish to remove #{rest_cartridge.name} from '#{rest_app.name}'?"

      say "Removing #{rest_cartridge.name} from '#{rest_app.name}' ... "
      rest_cartridge.destroy
      success "removed"

      0
    end

    summary "Start a cartridge"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are stopping", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartrdige belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge", :context => :app_context, :required => true
    alias_action :"app cartridge start", :root_command => true, :deprecated => true
    def start(cartridge)
      cartridge_action(cartridge, :start){ |_, c| results{ say "#{c.name} started" } }
      0
    end

    summary "Stop a cartridge"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are stopping", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application you the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge stop", :root_command => true, :deprecated => true
    def stop(cartridge)
      cartridge_action(cartridge, :stop){ |_, c| results{ say "#{c.name} stopped" } }
      0
    end

    summary "Restart a cartridge"
    syntax "<cartridge_type> [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are restarting", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge restart", :root_command => true, :deprecated => true
    def restart(cartridge)
      cartridge_action(cartridge, :restart){ |_, c| results{ say "#{c.name} restarted" } }
      0
    end

    summary "Get current the status of a cartridge"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are getting the status of", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge status", :root_command => true, :deprecated => true
    def status(cartridge)
      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first
      results { rest_cartridge.status.each{ |msg| say msg['message'] } }
      0
    end

    summary "Reload the cartridge's configuration"
    syntax "<cartridge> [--namespace namespace] [--app app]"
    argument :cart_type, "The name of the cartridge you are reloading", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge reload", :root_command => true, :deprecated => true
    def reload(cartridge)
      cartridge_action(cartridge, :reload){ |_, c| results{ say "#{c.name} reloaded" } }
      0
    end

    summary "Set the scaling range of a cartridge"
    syntax "<cartridge> [--namespace namespace] [--app app] [--min min] [--max max]"
    argument :cart_type, "The name of the cartridge you are reloading", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    option ["--min min", Integer], "Minimum scaling value"
    option ["--max max", Integer], "Maximum scaling value"
    def scale(cartridge)
      raise RHC::MissingScalingValueException unless options.min || options.max

      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first

      raise RHC::CartridgeNotScalableException unless rest_cartridge.scalable?

      cart = rest_cartridge.set_scales({
        :scales_from => options.min,
        :scales_to   => options.max
      })

      results do
        paragraph{ display_cart(cart) }
        success "Success: Scaling values updated"
      end

      0
    end

    summary 'View/manipulate storage on a cartridge'
    syntax '<cartridge> -a app [--show] [--add|--remove|--set amount] [--namespace namespace]'
    argument :cart_type, "The name of the cartridge", ["-c", "--cartridge cart_type"], :arg_type => :list
    option ["-n", "--namespace namespace"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app app"], "Application the cartridge belongs to", :context => :app_context, :required => true
    option ["--show"], "Show the current base and additional storage capacity"
    option ["--add amount"], "Add the indicated amount to the additional storage capacity"
    option ["--remove amount"], "Remove the indicated amount from the additional storage capacity"
    option ["--set amount"], "Set the specified amount of additional storage capacity"
    option ["-f", "--force"], "Force the action"
    def storage(cartridge)
      cartridges = Array(cartridge)
      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)

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
            check_cartridges(cartridge, :from => rest_app.cartridges).each do |cart|
              display_cart_storage_info cart, cart.display_name
            end
          end
        end
      else
        raise RHC::MultipleCartridgesException,
          'Exactly one cartridge must be specified for this operation' if cartridges.length != 1

        rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first
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

      def cartridge_action(cartridge, action, &block)
        rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
        rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first
        result = rest_cartridge.send action
        resp = [result, rest_cartridge, rest_app]
        yield resp if block_given?
        resp
      end
  end
end
