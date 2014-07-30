module RHC::Auth
  class X509
    def initialize(*args)
      @options = args[0] || Commander::Command::Options.new
    end

    def to_request(request, client=nil)
      request[:client_cert] = certificate_file(options.ssl_client_cert_file)
      request[:client_key] = rsa_key_file(options.ssl_client_key_file)
      request
    end

    def certificate_file(file)
      file && OpenSSL::X509::Certificate.new(IO.read(File.expand_path(file)))
    rescue => e
      debug e
      raise OptionParser::InvalidOption.new(nil, "The certificate '#{file}' cannot be loaded: #{e.message} (#{e.class})")
    end

    def rsa_key_file(file)
      file && OpenSSL::PKey::RSA.new(IO.read(File.expand_path(file)))
    rescue => e
      debug e
      raise OptionParser::InvalidOption.new(nil, "The RSA key '#{file}' cannot be loaded: #{e.message} (#{e.class})")
    end

    def retry_auth?(response, client)
      # This is really only hit in the case of token auth falling back to x509.
      # x509 auth doesn't usually get 401s.
      if response && response.status != 401
        false
      else
        true
      end
    end

    def can_authenticate?
      true
    end

    def expired_token_message
      "Your authorization token has expired.  " + get_token_message
    end

    def get_token_message
      "Fetching a new token from #{openshift_server}."
    end

    protected
      include RHC::Helpers
      attr_reader :options
  end
end
