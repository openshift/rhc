module RHC
  module Rest

    autoload :Base,          'rhc/rest/base'
    autoload :Attributes,    'rhc/rest/attributes'

    autoload :HTTPClient,    'rhc/rest/httpclient'

    autoload :Api,           'rhc/rest/api'
    autoload :Application,   'rhc/rest/application'
    autoload :Authorization, 'rhc/rest/authorization'
    autoload :Cartridge,     'rhc/rest/cartridge'
    autoload :Client,        'rhc/rest/client'
    autoload :Domain,        'rhc/rest/domain'
    autoload :Key,           'rhc/rest/key'
    autoload :User,          'rhc/rest/user'
    autoload :GearGroup,     'rhc/rest/gear_group'
    autoload :Alias,         'rhc/rest/alias'
    autoload :EnvironmentVariable,         'rhc/rest/environment_variable'

    class Exception < RuntimeError
      attr_reader :code
      def initialize(message=nil, code=1)
        super(message)
        @code = (Integer(code) rescue nil)
      end
    end

    #Exceptions thrown in case of an HTTP 5xx is received.
    class ServerErrorException < Exception; end

    #Exceptions thrown in case of an HTTP 503 is received.
    #
    #503 Service Unavailable
    #
    #The server is currently unable to handle the request due to a temporary 
    #overloading or maintenance of the server. The implication is that this 
    #is a temporary condition which will be alleviated after some delay.
    class ServiceUnavailableException < ServerErrorException; end

    #Exceptions thrown in case of an HTTP 4xx is received with the exception 
    #of 401, 403, 403 and 422 where a more sepcific exception is thrown
    #
    #HTTP Error Codes 4xx
    #
    #The 4xx class of status code is intended for cases in which the client 
    #seems to have errored.
    class ClientErrorException < Exception; end

    #Exceptions thrown in case of an HTTP 404 is received.
    #
    #404 Not Found
    #
    #The server has not found anything matching the Request-URI or the
    #requested resource does not exist
    class ResourceNotFoundException < ClientErrorException; end
    class ApiEndpointNotFound < ResourceNotFoundException; end

    # 404 errors for specific resource types
    class DomainNotFoundException < ResourceNotFoundException
      def initialize(msg)
        super(msg,127)
      end
    end
    class ApplicationNotFoundException < ResourceNotFoundException
      def initialize(msg)
        super(msg,101)
      end
    end

    #Exceptions thrown in case of an HTTP 422 is received.
    class ValidationException < ClientErrorException
      attr_reader :field
      def initialize(message, field=nil, error_code=1)
        super(message, error_code)
        @field = field
      end
    end

    #Exceptions thrown in case of an HTTP 403 is received.
    #
    #403 Forbidden
    #
    #The server understood the request, but is refusing to fulfill it.
    #Authorization will not help and the request SHOULD NOT be repeated. 
    class RequestDeniedException < ClientErrorException; end

    #Exceptions thrown in case of an HTTP 401 is received.
    #
    #401 Unauthorized
    #
    #The request requires user authentication.  If the request already 
    #included Authorization credentials, then the 401 response indicates 
    #that authorization has been refused for those credentials. 
    class UnAuthorizedException < ClientErrorException; end
    class TokenExpiredOrInvalid < UnAuthorizedException; end

    # DEPRECATED Unreachable host, SSL Exception
    class ResourceAccessException < Exception; end

    #I/O Exceptions Connection timeouts, etc
    class ConnectionException < Exception; end
    class TimeoutException < ConnectionException
      def initialize(message, nested=nil)
        super(message)
        @nested = nested
      end

      def on_receive?
        @nested.is_a? HTTPClient::ReceiveTimeoutError
      end
      def on_connect?
        @nested.is_a? HTTPClient::ConnectTimeoutError
      end
      def on_send?
        @nested.is_a? HTTPClient::SendTimeoutError
      end
    end

    class SSLConnectionFailed < ConnectionException
      attr_reader :reason
      def initialize(reason, message)
        super message
        @reason = reason
      end
    end
    class CertificateVerificationFailed < SSLConnectionFailed; end
    class SelfSignedCertificate < CertificateVerificationFailed; end

    class SSLVersionRejected < SSLConnectionFailed; end

    class MultipleCartridgeCreationNotSupported < Exception; end

    class DownloadingCartridgesNotSupported < Exception; end

    class InitialGitUrlNotSupported < Exception; end

    class SslCertificatesNotSupported < Exception; end

    class AuthorizationsNotSupported < Exception
      def initialize(message="The server does not support setting, retrieving, or authenticating with authorization tokens.")
        super(message, 1)
      end
    end
  end
end
