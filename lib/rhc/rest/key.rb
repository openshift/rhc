require 'rhc/rest/base'

module RHC
  module Rest
    class Key < Base
      attr_reader :name, :type, :content

      def update(type, content)
        debug "Updating key #{self.name}"
        rest_method "UPDATE", :type => type, :content => content
      end

      def destroy
        debug "Deleting key #{self.name}"
        rest_method "DELETE"
      end
      alias :delete :destroy

      def fingerprint
        begin
          public_key = Net::SSH::KeyFactory.load_data_public_key("#{type} #{content}")
          public_key.fingerprint
        rescue NotImplementedError, OpenSSL::PKey::PKeyError => e
          'Invalid key'
        end
      end
    end
  end
end
