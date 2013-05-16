module RHC
  module Rest
    class Alias < Base

      define_attr :id, :has_private_ssl_certificate, :certificate_added_at

      def has_private_ssl_certificate?
        has_private_ssl_certificate
      end

      def destroy
        debug "Deleting alias #{self.id}"
        rest_method :delete
      end
      alias :delete :destroy

      def add_certificate(ssl_certificate_content, private_key_content, pass_phrase)
        debug "Running add_certificate for alias #{@id}"
        raise RHC::Rest::SslCertificatesNotSupported, "The server does not support SSL certificates for custom aliases." unless supports? :update
        foo = rest_method :update, {
          :ssl_certificate => ssl_certificate_content, 
          :private_key => private_key_content, 
          :pass_phrase => pass_phrase
        }
      end

      def delete_certificate
        debug "Running delete_certificate for alias #{@id}"
        raise RHC::Rest::SslCertificatesNotSupported, "The server does not support SSL certificates for custom aliases." unless supports? :update
        rest_method :update, {}
      end

      def <=>(a)
        return self.name <=> a.name
      end

      def to_s
        self.id
      end
    end
  end
end