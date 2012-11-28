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
    # Application information
    #---------------------------
    def display_app(app,cartridges = nil)
      heading = "%s @ %s (uuid: %s)" % [app.name, app.app_url, app.uuid]
      paragraph do
        header heading do
          section(:bottom => 1) do
            display_app_properties(
              app,
              :creation_time,
              :gear_profile,
              :git_url,
              :ssh_string,
              :aliases)
          end
          display_included_carts(cartridges) if cartridges
        end
      end
    end

    def display_app_properties(app,*properties)
      say_table \
        nil,
        get_properties(app,*properties),
        :delete => true
    end

    def display_included_carts(carts)
      carts.each do |c|
        section(:bottom => 1) do
          say_table \
            format_cart_header(c),
            get_properties(c, :scaling, :connection_info),
            :delete => true
        end
      end
    end

    def format_cart_header(cart)
      [
        cart.name, 
        cart.name != cart.display_name ? "(#{cart.display_name})" : nil,
      ].compact.join(' ')
    end

    def format_scaling_info(scaling)
      "x%d (minimum: %s, maximum: %s) on %s gears" %
        [:current_scale, :scales_from, :scales_to, :gear_profile].map{ |key| format_value(key, scaling[key]) } if scaling
    end

    #---------------------------
    # Cartridge information
    #---------------------------

    def display_cart(cart, *properties)
      properties = [:scaling, :connection_info] if properties.empty?
      @table_displayed = false
      say_table \
        format_cart_header(cart),
        get_properties(cart, *properties),
        :delete => true
      display_no_info("cartridge") unless @table_displayed
    end

    #---------------------------
    # Misc information
    #---------------------------

    def display_no_info(type)
      say_table \
        nil,
        [["This #{type} has no information to show"]]
    end

    private
      def say_table(heading,values,opts = {})
        @table_displayed = true

        values = values.to_a if values.is_a? Hash
        values.delete_if do |arr|
          arr[0] = "#{table_heading(arr.first)}:" if arr[0].is_a? Symbol
          opts[:delete] and arr.last.blank?
        end

        table = self.table(values)

        # Make sure we nest properly
        if heading
          header heading do
            say table
          end
        else
          say table
        end
      end

      # This uses the array of properties to retrieve them from an object
      def get_properties(object,*properties)
        properties.map do |prop|
          # Either send the property to the object or yield it
          value = block_given? ? yield(prop) : object.send(prop)
          # Some values (like date) need some special handling

          [prop, format_value(prop,value)]
        end
      end

      # Format some special values
      def format_value(prop,value)
        case prop
        when :creation_time
          date(value)
        when :scales_from,:scales_to
          (value == -1 ? "available" : value)
        when :scaling
          format_scaling_info(value)
        when :aliases
          value.join ' '
        else
          value
        end
      end
  end
end
