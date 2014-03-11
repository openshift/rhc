module RHC
  module OutputHelpers

    def display_domain(domain, applications=nil, ids=false)
      paragraph do
        header ["Domain #{domain.name}", ("(owned by #{domain.owner})" if domain.owner.present?)] do
          section(:bottom => 1) do
            say format_table \
              nil,
              get_properties(
                domain,
                :creation_time,
                (:id if ids),
                (:allowed_gear_sizes unless domain.allowed_gear_sizes.nil?),
                :compact_members
              ),
              :delete => true
          end
          applications.each do |a|
            display_app(a,a.cartridges)
          end if applications.present?
        end
      end
    end

    #---------------------------
    # Application information
    #---------------------------
    def display_app(app, cartridges=nil, properties=nil)
      paragraph do
        header [app.name, "@ #{app.app_url}", "(uuid: #{app.uuid})"] do
          section(:bottom => 1) do
            say format_table \
              nil,
              get_properties(app, properties ||
                [:domain,
                :creation_time,
                :gear_info,
                :git_url,
                :initial_git_url,
                :ssh_string,
                :auto_deploy,
                :aliases]),
              :delete => true
          end
          cartridges.each{ |c| section(:bottom => 1){ display_cart(c) } } if cartridges
        end
      end
    end

    def display_app_configurations(rest_app)
      display_app(rest_app, nil, [:auto_deploy, :keep_deployments, :deployment_type, :deployment_branch])
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
          concat([[:downloaded_cartridge_url, cart.url]]).
          concat([[cart.scalable? ? :scaling : :gears, format_cart_gears(cart)]]).
          concat(cart.properties.map{ |p| ["#{table_heading(p['name'])}:", p['value']] }.sort{ |a,b| a[0] <=> b[0] }).
          concat(cart.environment_variables.present? ? [[:environment_variables, cart.environment_variables.map{|item| "#{item[:name]}=#{item[:value]}" }.sort.join(', ')]] : []),
        :delete => true

      say format_usage_message(cart) if cart.usage_rate?
    end

    def display_key(key, *properties)
      properties = [:fingerprint, :principal, :visible_to_ssh?] if properties.empty?
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
      cart.usage_rate_desc
    end

    def default_display_env_var(env_var_name, env_var_value=nil)
      info "#{env_var_name}#{env_var_value.nil? ? '' : '=' + env_var_value}"
    end

    def display_env_var_list(env_vars, opts={})
      if env_vars.present?
        if opts[:table]
          say table(env_vars.collect{ |item| [item.name, opts[:quotes] ? "\"#{item.value}\"" : item.value] }, :header => ['Name', 'Value'])
        else
          env_vars.sort.each do |env_var|
            default_display_env_var(env_var.name, opts[:quotes] ? "\"#{env_var.value}\"" : env_var.value)
          end
        end
      end
    end

    def display_deployment(item, highlight_active=true)
      deployment = item[:deployment]
      active = item[:active]
      paragraph do
        say format_table(
          "Deployment ID #{deployment.id} #{active ? '(active)' : '(inactive)'}",
          get_properties(deployment, :ref, :sha1, :created_at, :artifact_url, :hot_deploy, :force_clean_build, :activations),
          {
            :delete => true,
            :color => (:green if active && highlight_active)
          }
        )
      end
    end

    def display_deployment_list(deployment_activations, highlight_active=true)
      if deployment_activations.present?
        paragraph do
          deployment_activations.each do |item|
            activation = item[:activation]
            deployment = item[:deployment]
            rollback = item[:rollback]
            rollback_to = item[:rollback_to]
            rolled_back = item[:rolled_back]
            active = item[:active]
            say color(
              date(activation.created_at.to_s) +
              ', deployment ' + deployment.id +
              (rollback ? " (rollback to #{date(rollback_to.to_s)}#{rolled_back ? ', rolled back' : ''})" : rolled_back ? ' (rolled back)' : ''),
                active ? :green : rolled_back ? :yellow : nil)
          end
        end
      end
    end

    private
      def format_table(heading,values,opts = {})
        values = values.to_a if values.is_a? Hash
        values.delete_if do |arr|
          arr[0] = "#{table_heading(arr.first)}:" if arr[0].is_a? Symbol
          opts[:delete] and arr.last.nil? || arr.last == ""
        end

        table(values, :heading => heading, :indent => heading ? '  ' : nil, :color => opts[:color])
      end

      def format_no_info(type)
        ["This #{type} has no information to show"]
      end


      # This uses the array of properties to retrieve them from an object
      def get_properties(object,*properties)
        properties.flatten.map do |prop|
          # Either send the property to the object or yield it
          next if prop.nil?
          value = begin
                    block_given? ? yield(prop) : object.send(prop)
                  rescue ::Exception => e
                    debug_error(e)
                    "<error>"
                  end
          [prop, format_value(prop,value)]
        end.compact
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
        when :creation_time, :created_at
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
        when :activations
          value.collect{|item| date(item.created_at.to_s)}.join("\n")
        when :auto_deploy
          value ? 'auto (on git push)' : "manual (use 'rhc deploy')"
        else
          case value
          when Array then value.empty? ? '<none>' : value.join(', ')
          else            value
          end
        end
      end
  end
end
