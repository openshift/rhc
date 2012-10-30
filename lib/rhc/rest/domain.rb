require 'rhc/rest/base'

module RHC
  module Rest
    class Domain < Base
      attr_reader :id

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
        timeout = nil
        if options[:scale]
          timeout = 300 # 5 minute timeout for scalable app
        end

        rest_method "ADD_APPLICATION", payload, timeout
      end

      def applications
        debug "Getting all applications for domain #{id}"
        rest_method "LIST_APPLICATIONS"
      end

      def update(new_id)
        debug "Updating domain #{id} to #{new_id}"
        # 5 minute timeout as this may take time if there are a lot of apps
        rest_method "UPDATE", {:id => new_id}, 300
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
          return app if (name.nil? or app.name == name) and (framework.nil? or app.framework == framework)
        end

        raise RHC::ApplicationNotFoundException.new("Application #{name} does not exist")
      end
    end
  end
end
