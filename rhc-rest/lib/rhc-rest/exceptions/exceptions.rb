# Copyright 2011 Red Hat, Inc.
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

module Rhc
  module Rest
    class BaseException < RuntimeError
      attr_reader :code
      def initialize(msg=nil, code=nil)
        super(msg)
        @code = code
      end
    end

    #Exceptions thrown in case of an HTTP 5xx is received.
    class ServerErrorException < Rhc::Rest::BaseException; end

    #Exceptions thrown in case of an HTTP 503 is received.
    #
    #503 Service Unavailable
    #
    #The server is currently unable to handle the request due to a temporary 
    #overloading or maintenance of the server. The implication is that this 
    #is a temporary condition which will be alleviated after some delay.
    
    class ServiceUnavailableException < Rhc::Rest::ServerErrorException; end

    #Exceptions thrown in case of an HTTP 4xx is received with the exception 
    #of 401, 403, 403 and 422 where a more sepcific exception is thrown
    #
    #HTTP Error Codes 4xx
    #
    #The 4xx class of status code is intended for cases in which the client 
    #seems to have errored.
    
    
    class ClientErrorException < Rhc::Rest::BaseException; end

    #Exceptions thrown in case of an HTTP 404 is received.
    #
    #404 Not Found
    #
    #The server has not found anything matching the Request-URI or the
    #requested resource does not exist
    class ResourceNotFoundException < Rhc::Rest::ClientErrorException; end

    #Exceptions thrown in case of an HTTP 422 is received.
    class ValidationException < Rhc::Rest::ClientErrorException
      attr_reader :error_code, :message, :attribute
      def initialize(messages)
        if not messages.nil?

        end
      end
    end

    #Exceptions thrown in case of an HTTP 403 is received.
    #
    #403 Forbidden
    #
    #The server understood the request, but is refusing to fulfill it.
    #Authorization will not help and the request SHOULD NOT be repeated. 
    class RequestDeniedException < Rhc::Rest::ClientErrorException; end

    #Exceptions thrown in case of an HTTP 401 is received.
    #
    #401 Unauthorized
    #
    #The request requires user authentication.  If the request already 
    #included Authorization credentials, then the 401 response indicates 
    #that authorization has been refused for those credentials. 
    class UnAuthorizedException < Rhc::Rest::ClientErrorException; end

    #I/O Exceptions
    class ResourceAccessException < Rhc::Rest::BaseException; end

  end
end