module RHC
  module OutputHelpers
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

    #---------------------------
    # Domain information
    #---------------------------

    # This is a little different because we don't want to recreate the display_app function
    def display_domain(domain)
      say "No domain exists.  You can use 'rhc domain create' to create a namespace for applications." and return unless domain
      header "Applications in %s" % domain.id do
        domain.applications.each do |a|
          display_app(a,a.cartridges,a.scalable_carts.first)
        end.blank? and say "No applications. You can use 'rhc app create' to create new applications."
      end
    end

    #---------------------------
    # Application information
    #---------------------------
    def display_app(app,cartridges = nil,scalable_cart = nil)
      heading = "%s @ %s" % [app.name, app.app_url]
      paragraph do
        header heading do
          display_app_properties(app,:creation_time,:uuid,:gear_profile,:git_url,:ssh_url,:aliases)
          display_included_carts(cartridges) if cartridges
          display_scaling_info(app,scalable_cart) if scalable_cart
        end
      end
    end

    def display_app_properties(app,*properties)
      say_table \
        "Application Info",
        get_properties(app,*properties),
        :delete => true
    end

    def display_included_carts(carts)
      properties = Hash[carts.map do |cart|
        [cart.name,cart.connection_info]
      end]

      properties = "None" unless properties.present?

      say_table \
        "Cartridges",
        properties,
        :preserve_keys => true
    end

    def display_scaling_info(app,cart)
      # Save these values for easier reuse
      values = [:current_scale,:scales_from,:scales_to,:scales_with]
      # Get the scaling properties we care about
      properties = get_properties(cart,*values)
      # Format the string for applications
      properties = "Scaled x%d (minimum: %s, maximum: %s) with %s on %s gears" %
        [properties.values_at(*values), app.gear_profile].flatten

      say_table \
        "Scaling Info",
        properties
    end

    #---------------------------
    # Cartridge information
    #---------------------------

    def display_cart(cart,properties = nil)
      @table_displayed = false
      header cart.name do
        display_cart_properties(cart,properties) if properties
        display_cart_scaling_info(cart) if cart.scalable?
        display_cart_storage_info(cart) if cart.additional_gear_storage > 0
        display_no_info("cartridge") unless @table_displayed
      end
    end

    def display_cart_properties(cart,properties)
      # We need to actually access the cart because it's not a simple hash
      properties = get_properties(cart,*properties.keys) do |prop|
        cart.property(:cart_data,prop)["value"]
      end

      say_table \
        "Properties",
        properties
    end

    def display_cart_scaling_info(cart)
      say_table \
        "Scaling Info",
        get_properties(cart,:current_scale,:scales_from,:scales_to)
    end

    def display_cart_storage_info(cart, title="Storage Info")
      say_table \
        title,
        get_properties(cart,:base_gear_storage,:additional_gear_storage)
    end

    def display_cart_storage_list(carts)
      carts.each do |cart|
        puts
        display_cart_storage_info(cart, cart.display_name)
      end
    end

    #---------------------------
    # Misc information
    #---------------------------

    def display_no_info(type)
      say_table \
        nil,
        ["This #{type} has no information to show"]
    end

    private
      def say_table(heading,values,opts = {})
        @table_displayed = true
        table = make_table(values,opts)

        # Go through all the table rows
        _proc = proc{
          table.each do |s|
            # Remove trailing = (like for cartridges list)
            indent s.gsub(/\s*=\s*$/,'')
          end
        }

        # Make sure we nest properly
        if heading
          header heading do
            _proc.call
          end
        else
          _proc.call
        end
      end

      # This uses the array of properties to retrieve them from an object
      def get_properties(object,*properties)
        Hash[properties.map do |prop|
          # Either send the property to the object or yield it
          value = block_given? ? yield(prop) : object.send(prop)
          # Some values (like date) need some special handling
          value = format_value(prop,value)

          [prop,value]
        end]
      end

      # Format some special values
      def format_value(prop,value)
        case prop
        when :creation_time
          date(value)
        when :scales_from,:scales_to
          (value == -1 ? "available gears" : value)
        when :base_gear_storage,:additional_gear_storage
          ((value.nil? or value == 0) ? "None" : "#{value}GB")
        when :aliases
          value.join ' '
        else
          value
        end
      end

      # Make the rows for the table
      #   If we pass a hash, it will manipulate it into a nice table
      #   Arrays and single vars will just be passed back as arrays
      def make_table(values,opts = {})
        case values
        when Hash
          # Loop through the values in case we need to fix them
          _values = values.inject({}) do |h,(k,v)|
            # Format the keys based on the table_heading function
            #  If we pass :preserve_keys, we leave them alone (like for cart names)
            key = opts[:preserve_keys] ? k : table_heading(k)

            # Replace empty or nil values with spaces
            #  If we pass :delete, we assume those are not needed
            if v.blank?
              h[key] = "" unless opts[:delete]
            else
              h[key] = v.to_s
            end
            h
          end
          # Join the values into rows
          table _values, :join => " = "
          # Create a simple array
        when Array
          values
        else
          [values]
        end
      end
  end
end
