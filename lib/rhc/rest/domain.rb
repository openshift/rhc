module RHC
  module Rest
    class Domain < Base
      define_attr :id

      #Add Application to this domain
      # options
      # cartrdige
      # template
      # scale
      # gear_profile
      def add_application(name, options)
        debug "Adding application #{name} to domain #{id}"

        payload = {:name => name}
        options.each{ |key, value| payload[key.to_sym] = value }

        cartridges = Array(payload.delete(:cartridge)).concat(Array(payload.delete(:cartridges))).compact.uniq
        if (client.api_version_negotiated >= 1.3)
          payload[:cartridges] = cartridges
        else
          raise RHC::Rest::MultipleCartridgeCreationNotSupported, "The server only supports creating an application with a single web cartridge." if cartridges.length > 1
          payload[:cartridge] = cartridges.first
        end

        options = {:timeout => options[:scale] && 0 || nil}
        rest_method "ADD_APPLICATION", payload, options
      end

      def applications(options = {})
        debug "Getting all applications for domain #{id}"
        rest_method "LIST_APPLICATIONS", options
      end

      def update(new_id)
        debug "Updating domain #{id} to #{new_id}"
        # 5 minute timeout as this may take time if there are a lot of apps
        rest_method "UPDATE", {:id => new_id}, {:timeout => 0}
      end
      alias :save :update

      def destroy(force=false)
        debug "Deleting domain #{id}"
        rest_method "DELETE", :force => force
      end
      alias :delete :destroy

      def find_application(name, options={})
        if name.is_a?(Hash)
          options = name.merge(options)
          name = options[:name]
        end
        framework = options[:framework]

        debug "Finding application :name => #{name}, :framework => #{framework}"
        applications.each do |app|
          return app if (name.nil? or app.name.downcase == name.downcase) and (framework.nil? or app.framework == framework)
        end

        raise RHC::ApplicationNotFoundException.new("Application #{name} does not exist")
      end
    end
  end
end
