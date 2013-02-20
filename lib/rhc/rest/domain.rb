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
        options.each do |key, value|
          payload[key] = value
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
    end
  end
end
