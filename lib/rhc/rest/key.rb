module RHC
  module Rest
    class Key < Base
      define_attr :name, :type, :content

      def is_ssh?
        type != 'krb5-principal'
      end

      def is_kerberos?
        type == 'krb5-principal'
      end

      def update(type, content)
        debug "Updating key #{self.name}"
        rest_method "UPDATE", :type => type, :content => content
      end

      def destroy
        debug "Deleting key #{self.name}"
        rest_method "DELETE"
      end
      alias :delete :destroy

      def principal
        content if is_kerberos?
      end

      def fingerprint
        @fingerprint ||= begin
          public_key = Net::SSH::KeyFactory.load_data_public_key("#{type} #{content}")
          public_key.fingerprint
        rescue NotImplementedError, OpenSSL::PKey::PKeyError => e
          'Invalid key'
        end if is_ssh?
      end

      def visible_to_ssh?
        Net::SSH::Authentication::Agent.connect.identities.
          find{ |i| fingerprint == i.fingerprint }.present? rescue false
      end
    end
  end
end
