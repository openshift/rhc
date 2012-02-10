module Rhc
  module Rest
    class BaseException < RuntimeError
      attr_reader :error_code, :message
      def initialize(messages)
        if not messages.nil?
          messages.each do |message|
            message += message['text']
          end
        end
      end
    end

    #Server Exceptions
    class ServerErrorException < Rhc::Rest::BaseException; end

    class ServiceUnavailableException < Rhc::Rest::ServerErrorException; end

    # Client Exceptions
    class ClientErrorException < Rhc::Rest::BaseException; end

    class ResourceNotFoundException < Rhc::Rest::ClientErrorException; end

    class ValidationException < Rhc::Rest::ClientErrorException
      attr_reader :error_code, :message, :attribute
      def initialize(messages)
        if not messages.nil?
          
        end
      end
    end

    class RequestDeniedException < Rhc::Rest::ClientErrorException; end

    class UnAuthorizedException < Rhc::Rest::ClientErrorException; end

    #I/O Exceptions
    class ResourceAccessException < Rhc::Rest::BaseException; end

  end
end