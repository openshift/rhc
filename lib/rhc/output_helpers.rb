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
      paragraph do
        header [app.name, "@ #{app.app_url}", "(uuid: #{app.uuid})"] do
          section(:bottom => 1) do
            say format_table \
              nil,
              get_properties(
                app,
                :creation_time,
                :gear_info,
                :git_url,
                :initial_git_url,
                :ssh_string,
                :aliases
              ),
              :delete => true
          end
          cartridges.each{ |c| section(:bottom => 1){ display_cart(c) } } if cartridges
        end
      end
    end

    def format_cart_header(cart)
      [
        cart.name,
        cart.name != cart.display_name ? "(#{cart.display_name})" : nil,
      ].compact
    end

    def format_scaling_info(scaling)
      "x%d (minimum: %s, maximum: %s) on %s gears" %
        [:current_scale, :scales_from, :scales_to, :gear_profile].map{ |key| format_value(key, scaling[key]) } if scaling
    end

    def format_cart_gears(cart)
      if cart.scalable?
        format_scaling_info(cart.scaling)
      elsif cart.shares_gears?
        "Located with #{cart.collocated_with.join(", ")}"
      else
        "%d %s" % [format_value(:current_scale, cart.current_scale), format_value(:gear_profile, cart.gear_profile)]
      end
    end

    def format_gear_info(info)
      "%d (defaults to %s)" %
        [:gear_count, :gear_profile].map{ |key| format_value(key, info[key]) } if info
    end

    #---------------------------
    # Cartridge information
    #---------------------------

    def display_cart(cart, *properties)
      say format_table \
        format_cart_header(cart),
        get_properties(cart, *properties).
          concat([[cart.scalable? ? :scaling : :gears, format_cart_gears(cart)]]).
          concat(cart.properties.map{ |p| ["#{table_heading(p['name'])}:", p['value']] }.sort{ |a,b| a[0] <=> b[0] }),
        :delete => true
      
      say format_usage_message(cart) if cart.usage_rate?
    end

    def display_key(key, *properties)
      properties = [:fingerprint, :visible_to_ssh?] if properties.empty?
      say format_table(
        properties.include?(:name) ? nil : format_key_header(key),
        get_properties(key, *properties),
        {
          :delete => true,
          :color => (:green if properties.include?(:visible_to_ssh?) && key.visible_to_ssh?),
        }
      )
    end

    def display_authorization(auth, default=nil)
      say format_table(
        auth.note || "<no description>",
        get_properties(auth, :token, :scopes, :creation_time, :expires_in_seconds),
        {
          :delete => true,
          :color => (:green if auth.token == default),
        }
      )
    end

    def format_key_header(key)
      [
        key.name,
        "(type: #{key.type})",
      ].compact
    end

    def display_cart_storage_info(cart, title="Storage Info")
      say format_table \
        title,
        get_properties(cart,:base_gear_storage,:additional_gear_storage)
    end

    def display_cart_storage_list(carts)
      carts.each{ |cart| paragraph{ display_cart_storage_info(cart, cart.display_name) } }
    end

    def format_usage_message(cart)
      "This gear costs an additional $#{cart.usage_rate} per gear after the first 3 gears."
    end

    private
      def format_table(heading,values,opts = {})
        values = values.to_a if values.is_a? Hash
        values.delete_if do |arr|
          arr[0] = "#{table_heading(arr.first)}:" if arr[0].is_a? Symbol
          opts[:delete] and arr.last.blank?
        end

        table(values, :heading => heading, :indent => heading ? '  ' : nil)
      end

      def format_no_info(type)
        ["This #{type} has no information to show"]
      end


      # This uses the array of properties to retrieve them from an object
      def get_properties(object,*properties)
        properties.map do |prop|
          # Either send the property to the object or yield it
          value = begin
                    block_given? ? yield(prop) : object.send(prop)
                  rescue ::Exception => e
                    debug_error(e)
                    "<error>"
                  end
          [prop, format_value(prop,value)]
        end
      end

      # Format some special values
      def format_value(prop,value)
        case prop
        when :plan_id
          case value
          when 'free' then 'Free'
          when 'silver' then 'Silver'
          else value && value.capitalize || nil
          end
        when :visible_to_ssh?
          value || nil
        when :creation_time
          date(value)
        when :scales_from,:scales_to
          (value == -1 ? "available" : value)
        when :gear_info
          format_gear_info(value)
        when :base_gear_storage,:additional_gear_storage
          ((value.nil? or value == 0) ? "None" : "#{value}GB")
        when :aliases
          value.kind_of?(Array) ? value.join(', ') : value
        when :expires_in_seconds
          distance_of_time_in_words(value)
        else
          case value
          when Array then value.join(', ')
          else            value
          end
        end
      end
  end
end
