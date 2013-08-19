require 'rhc/commands/base'
require 'rhc/cartridge_helpers'

module RHC::Commands
  class Cartridge < Base
    summary "Manage your application cartridges"
    syntax "<action>"
    description <<-DESC
      Cartridges add functionality to OpenShift applications.  Each application
      has one web cartridge to listen for HTTP requests, and any number
      of addon cartridges.  Addons may include databases like MySQL and Mongo,
      administrative tools like phpMyAdmin, or build clients like Jenkins.

      Most cartridges that listen for incoming network traffic are placed on
      one or more gears (a small server instance).  Other cartridges may be
      available across all of the gears of an application to listen for changes
      (like Jenkins) or provide environment variables.

      Use the 'cartridges' command to see a list of all available cartridges.
      Add a new cartridge to your application with 'add-cartridge'. OpenShift
      also supports downloading cartridges - pass a URL in place of the cartridge
      name and we'll download and install that cartridge into your app.  Keep
      in mind that these cartridges receive no security updates.  Note that
      not all OpenShift servers allow downloaded cartridges.

      For scalable applications, use the 'cartridge-scale' command on the web
      cartridge to set the minimum and maximum scale.

      Commands that affect a cartridge within an application will affect all
      gears the cartridge is installed to.
      DESC
    alias_action :"app cartridge", :root_command => true, :deprecated => true
    default_action :list

    summary "List available cartridges"
    syntax ''
    option ["-v", "--verbose"], "Display more details about each cartridge"
    alias_action :"app cartridge list", :root_command => true, :deprecated => true
    alias_action :"cartridges", :root_command => true
    def list
      carts = rest_client.cartridges.sort_by{ |c| "#{c.type == 'standalone' && 1}_#{c.tags.include?('experimental') ? 1 : 0}_#{(c.display_name || c.name).downcase}" }

      pager

      if options.verbose
        carts.each do |c|
          paragraph do
            name = c.name
            name += '*' if c.usage_rate?
            name = c.display_name != c.name && "#{color(c.display_name, :cyan)} [#{name}]" || name
            tags = c.tags - RHC::Rest::Cartridge::HIDDEN_TAGS
            say header([name, "(#{c.only_in_existing? ? 'addon' : 'web'})"])
            say c.description
            paragraph{ say "Tagged with: #{tags.sort.join(', ')}" } if tags.present?
            paragraph{ say format_usage_message(c) } if c.usage_rate?
          end
        end
      else
        say table(carts.collect do |c|
          [c.usage_rate? ? "#{c.name} (*)" : c.name,
           c.display_name,
           c.only_in_existing? ? 'addon' : 'web']
        end)
      end

      paragraph{ say "Note: Web cartridges can only be added to new applications." }
      paragraph{ say "(*) denotes a cartridge with additional usage costs." } if carts.any? { |c| c.usage_rate? }

      0
    end

    summary "Add a cartridge to your application"
    syntax "<cartridge_type> [--namespace NAME] [--app NAME]"
    option ["-n", "--namespace NAME"], "Namespace of the application you are adding the cartridge to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application you are adding the cartridge to", :context => :app_context, :required => true
    option ["-e", "--env VARIABLE=VALUE"], "Environment variable(s) to be set on this cartridge, or path to a file containing environment variables"
    argument :cart_type, "The type of the cartridge you are adding (run 'rhc cartridge list' to obtain a list of available cartridges)", ["-c", "--cartridge cart_type"]
    alias_action :"app cartridge add", :root_command => true, :deprecated => true
    def add(cart_type)
      cart = check_cartridges(cart_type, :from => not_standalone_cartridges).first

      say "Adding #{cart.short_name} to application '#{options.app}' ... "

      say format_usage_message(cart) if cart.usage_rate?

      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)

      cart.environment_variables = collect_env_vars(options.env).map { |item| item.to_hash } if options.env

      rest_cartridge = rest_app.add_cartridge(cart)

      success "done"

      rest_cartridge.environment_variables = cart.environment_variables if cart.environment_variables.present?

      paragraph{ display_cart(rest_cartridge) }
      paragraph{ say "Use 'rhc env --help' to manage environment variable(s) on this cartridge and application." }
      paragraph{ rest_cartridge.messages.each { |msg| success msg } }

      0
    end

    summary "Show useful information about a cartridge"
    syntax "<cartridge> [--namespace NAME] [--app NAME]"
    option ["-n", "--namespace NAME"], "Namespace of the application you are adding the cartridge to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application you are adding the cartridge to", :context => :app_context, :required => true
    argument :cartridge, "The name of the cartridge", ["-c", "--cartridge cart_type"]
    def show(cartridge)
      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first

      display_cart(rest_cartridge)

      0
    end

    summary "Remove a cartridge from your application"
    syntax "<cartridge> [--namespace NAME] [--app NAME]"
    argument :cartridge, "The name of the cartridge you are removing", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace NAME"], "Namespace of the application you are removing the cartridge from", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application you are removing the cartridge from", :context => :app_context, :required => true
    option ["--confirm"], "Pass to confirm removing the cartridge"
    alias_action :"app cartridge remove", :root_command => true, :deprecated => true
    def remove(cartridge)
      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first

      confirm_action "Removing a cartridge is a destructive operation that may result in loss of data associated with the cartridge.\n\nAre you sure you wish to remove #{rest_cartridge.name} from '#{rest_app.name}'?"

      say "Removing #{rest_cartridge.name} from '#{rest_app.name}' ... "
      rest_cartridge.destroy
      success "removed"

      paragraph{ rest_cartridge.messages.each { |msg| success msg } }

      0
    end

    summary "Start a cartridge"
    syntax "<cartridge> [--namespace NAME] [--app NAME]"
    argument :cart_type, "The name of the cartridge you are stopping", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application the cartridge", :context => :app_context, :required => true
    alias_action :"app cartridge start", :root_command => true, :deprecated => true
    def start(cartridge)
      cartridge_action(cartridge, :start, 'Starting %s ... ')
      0
    end

    summary "Stop a cartridge"
    syntax "<cartridge> [--namespace NAME] [--app NAME]"
    argument :cart_type, "The name of the cartridge you are stopping", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge stop", :root_command => true, :deprecated => true
    def stop(cartridge)
      cartridge_action(cartridge, :stop, 'Stopping %s ... ')
      0
    end

    summary "Restart a cartridge"
    syntax "<cartridge_type> [--namespace NAME] [--app NAME]"
    argument :cart_type, "The name of the cartridge you are restarting", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge restart", :root_command => true, :deprecated => true
    def restart(cartridge)
      cartridge_action(cartridge, :restart, 'Restarting %s ... ')
      0
    end

    summary "Get current the status of a cartridge"
    syntax "<cartridge> [--namespace NAME] [--app NAME]"
    argument :cart_type, "The name of the cartridge you are getting the status of", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge status", :root_command => true, :deprecated => true
    def status(cartridge)
      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first
      results { rest_cartridge.status.each{ |msg| say msg['message'] } }
      0
    end

    summary "Reload the cartridge's configuration"
    syntax "<cartridge> [--namespace NAME] [--app NAME]"
    argument :cart_type, "The name of the cartridge you are reloading", ["-c", "--cartridge cartridge"]
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application the cartridge belongs to", :context => :app_context, :required => true
    alias_action :"app cartridge reload", :root_command => true, :deprecated => true
    def reload(cartridge)
      cartridge_action(cartridge, :reload, 'Reloading %s ... ')
      0
    end

    summary "Set the scale range for a cartridge"
    description <<-DESC
      Each cartridge capable of scaling may have a minimum and a maximum set, although within that range
      each type of cartridge may make decisions to autoscale.  Web cartridges will scale based on incoming
      request traffic - see https://www.openshift.com/developers/scaling for more information. Non web
      cartridges such as databases may require specific increments of scaling (1, 3, 5) in order to
      properly function.  Please consult the cartridge documentation for more on specifics of scaling.

      Set both values the same to guarantee a scale value.  You may pecify both values with the argument
      'multiplier' or use '--min' and '--max' independently.

      Scaling may take several minutes or more if the server must provision multiple gears. Your operation
      will continue in the background if your client is disconnected.
      DESC
    syntax "<cartridge> [multiplier] [--namespace NAME] [--app NAME] [--min min] [--max max]"
    argument :cartridge, "The name of the cartridge you are scaling", ["-c", "--cartridge cartridge"]
    argument :multiplier, "The number of instances of this cartridge you need", [], :optional => true, :hide => true
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application the cartridge belongs to", :context => :app_context, :required => true
    option ["--min min", Integer], "Minimum scaling value"
    option ["--max max", Integer], "Maximum scaling value"
    def scale(cartridge, multiplier)
      options.default(:min => Integer(multiplier), :max => Integer(multiplier)) if multiplier rescue raise ArgumentError, "Multiplier must be a positive integer."

      raise RHC::MissingScalingValueException unless options.min || options.max

      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first

      raise RHC::CartridgeNotScalableException unless rest_cartridge.scalable?

      warn "This operation will run until the application is at the minimum scale and may take several minutes."
      say "Setting scale range for #{rest_cartridge.name} ... "

      cart = rest_cartridge.set_scales({
        :scales_from => options.min,
        :scales_to   => options.max
      })

      success "done"
      paragraph{ display_cart(cart) }

      0
    rescue RHC::Rest::TimeoutException => e
      raise unless e.on_receive?
      info "The server has closed the connection, but your scaling operation is still in progress.  Please check the status of your operation via 'rhc show-app'."
      1
    end

    summary 'View/manipulate storage on a cartridge'
    syntax '<cartridge> -a app [--show] [--add|--remove|--set amount] [--namespace NAME]'
    argument :cart_type, "The name of the cartridge", ["-c", "--cartridge cart_type"], :arg_type => :list
    option ["-n", "--namespace NAME"], "Namespace of the application the cartridge belongs to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application the cartridge belongs to", :context => :app_context, :required => true
    option ["--show"], "Show the current base and additional storage capacity"
    option ["--add amount"], "Add the indicated amount to the additional storage capacity"
    option ["--remove amount"], "Remove the indicated amount from the additional storage capacity"
    option ["--set amount"], "Set the specified amount of additional storage capacity"
    option ["-f", "--force"], "Force the action"
    def storage(cartridge)
      cartridges = Array(cartridge)
      rest_app = rest_client(:min_api => 1.3).find_application(options.namespace, options.app, :include => :cartridges)

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

        say "Set storage on cartridge ... "
        cart = rest_cartridge.set_storage(:additional_gear_storage => total_amount)
        success "set to #{total_amount}GB"
        paragraph{ display_cart_storage_info cart }
      end

      0
    end

    private
      include RHC::CartridgeHelpers

      def cartridge_action(cartridge, action, message=nil)
        rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
        rest_cartridge = check_cartridges(cartridge, :from => rest_app.cartridges).first
        say message % [rest_cartridge.name] if message
        result = rest_cartridge.send(action)
        resp = [result, rest_cartridge, rest_app]
        if message
          success "done"
          result.messages.each{ |s| paragraph{ say s } }
        end
        resp
      end
  end
end
