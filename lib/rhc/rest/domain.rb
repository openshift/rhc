module RHC
  module Rest
    class Domain < Base
      include Membership

      define_attr :id, :allowed_gear_sizes, :creation_time

      def allowed_gear_sizes
        Array(attribute(:allowed_gear_sizes))
      end

      #Add Application to this domain
      # options
      # cartridge
      # template
      # scale
      # gear_profile
      def add_application(name, options)
        debug "Adding application #{name} to domain #{id}"

        payload = {:name => name}
        options.each{ |key, value| payload[key.to_sym] = value }

        cartridges = Array(payload.delete(:cartridge)).concat(Array(payload.delete(:cartridges))).map do |cart|
            if cart.is_a? String or cart.respond_to? :[]
              cart
            else
              cart.url ? {:url => cart.url} : cart.name
            end
          end.compact.uniq

        if cartridges.any?{ |c| c.is_a?(Hash) and c[:url] } and !has_param?('ADD_APPLICATION', 'cartridges[][url]')
          raise RHC::Rest::DownloadingCartridgesNotSupported, "The server does not support downloading cartridges."
        end

        if client.api_version_negotiated >= 1.3
          payload[:cartridges] = cartridges
        else
          raise RHC::Rest::MultipleCartridgeCreationNotSupported, "The server only supports creating an application with a single web cartridge." if cartridges.length > 1
          payload[:cartridge] = cartridges.first
        end

        if payload[:initial_git_url] and !has_param?('ADD_APPLICATION', 'initial_git_url')
          raise RHC::Rest::InitialGitUrlNotSupported, "The server does not support creating applications from a source repository."
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
