require 'logger'
require 'rest-client'

module RHC
  module Rest

    autoload :Application, 'rhc/rest/application'
    autoload :Cartridge,   'rhc/rest/cartridge'
    autoload :Client,      'rhc/rest/client'
    autoload :Domain,      'rhc/rest/domain'
    autoload :Key,         'rhc/rest/key'
    autoload :User,        'rhc/rest/user'
    autoload :GearGroup,   'rhc/rest/gear_group'

    class Exception < RuntimeError
      attr_reader :code
      def initialize(message=nil, code=nil)
        super(message)
        @code = code
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

    #Exceptions thrown in case of an HTTP 422 is received.
    class ValidationException < ClientErrorException
      attr_reader :field
      def initialize(message, field=nil, error_code=nil)
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

    # Unreachable host, SSL Exception
    class ResourceAccessException < Exception; end

    #I/O Exceptions Connection timeouts, etc
    class ConnectionException < Exception; end
    class TimeoutException < ConnectionException; end
  end


  module Rest
    def logger
      Logger.new(STDOUT)
    end

    def parse_response(response)
      result = RHC::Json.decode(response)
      type = result['type']
      data = result['data']
      case type
      when 'domains'
        domains = Array.new
        data.each do |domain_json|
          dom = Domain.new(domain_json, @debug, @api_version)
          dom.set_auth_header(@user, @pass)
          domains.push(dom)
        end
        return domains
      when 'domain'
        dom = Domain.new(data, @debug, @api_version)
        dom.set_auth_header(@user, @pass)
        return dom
      when 'applications'
        apps = Array.new
        data.each do |app_json|
          app = Application.new(app_json, @debug, @api_version)
          app.set_auth_header(@user, @pass)
          apps.push(app)
        end
        return apps
      when 'application'
        app = Application.new(data, @debug, @api_version)
        app.set_auth_header(@user, @pass)
        result['messages'].each do |message|
          app.add_message(message['text']) if message['field'].nil? or message['field'] == 'result'
        end
        return app
      when 'cartridges'
        carts = Array.new
        data.each do |cart_json|
          cart = Cartridge.new(cart_json, @debug, @api_version)
          cart.set_auth_header(@user, @pass)
          carts.push(cart)
        end
        return carts
      when 'cartridge'
        cart = Cartridge.new(data, @debug, @api_version)
        cart.set_auth_header(@user, @pass)
        return cart
      when 'user'
        user = User.new(data, @debug, @api_version)
        user.set_auth_header(@user, @pass)
        return user
      when 'keys'
        keys = Array.new
        data.each do |key_json|
          key = Key.new(key_json, @debug, @api_version)
          key.set_auth_header(@user, @pass)
          keys.push(key)
        end
        return keys
      when 'key'
        key = Key.new(data, @debug, @api_version)
        key.set_auth_header(@user, @pass)
        return key
      when 'gear_groups'
        gears = Array.new
        data.each do |gear_json|
          g = GearGroup.new(gear_json, @debug, @api_version)
          g.set_auth_header(@user, @pass)
          gears.push(g)
        end
        return gears
      else
        data
      end
    end

    def new_request(options)
      # user specified timeout takes presidence
      options[:timeout] = $rest_timeout || options[:timeout]

      RestClient::Request.new options
    end

    def request(request)
      begin
        @headers = request.headers
        response = request.execute
        #set cookie
        rh_sso = response.cookies['rh_sso']
        if not rh_sso.nil?
          @headers["cookie"] = "rh_sso=#{rh_sso}"
        end
        return parse_response(response) unless response.nil? or response.code == 204
      rescue RestClient::RequestTimeout => e
        raise TimeoutException.new("Connection to server timed out. It is possible the operation finished without being able to report success. Use 'rhc domain show' or 'rhc app status' to check the status of your applications.") 
      rescue RestClient::ServerBrokeConnection => e
        raise ConnectionException.new("Connection to server got interrupted: #{e.message}")
      rescue RestClient::ExceptionWithResponse => e
        process_error_response(e.response)
      rescue => e
        raise ResourceAccessException.new("Failed to access resource: #{e.message}")
      end
    end

    def process_error_response(response)
      messages = Array.new
      begin
        result = RHC::Json.decode(response)
        messages = result['messages']
      rescue => e
        logger.debug "Response did not include a message from server" if @mydebug
      end
      case response.code
      when 401
        raise UnAuthorizedException, "Not authenticated"
      when 403
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise RequestDeniedException, message['text']
          end
        end
      when 404
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ResourceNotFoundException, message['text']
          end
        end
      when 409
        messages.each do |message|
          if message['severity'] and message['severity'].upcase == "ERROR"
            raise ValidationException, message['text']
          end
        end
      when 422
        #puts response
        e = nil
        messages.each do |message|
          if e and e.field == message["field"]
            e.message << " #{message["text"]}"
          else
            e = ValidationException.new(message["text"], message["field"], message["code"])
          end
        end
        raise e
      when 400
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ClientErrorException, message['text']
          end
        end
      when 500
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ServerErrorException, message['text']
          end
        end
      when 503
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ServiceUnavailableException, message['text']
          end
        end
      else
        raise ResourceAccessException, "Server returned error code with no output: #{response.code}"
      end
    end
  end
end
