require 'rest-client'
require 'logger'
require 'rhc-rest/exceptions/exceptions'
require 'rhc-rest/application'
require 'rhc-rest/cartridge'
require 'rhc-rest/client'
require 'rhc-rest/domain'
require 'rhc-rest/key'
require 'rhc-rest/user'

module Rhc
  module Rest
    @@headers = {:accept => :json}

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
          domains.push(Domain.new(domain_json))
        end
        return domains
      when 'domain'
        return Domain.new(data)
      when 'applications'
        apps = Array.new
        data.each do |app_json|
          apps.push(Application.new(app_json))
        end
        return apps
      when 'application'
        return Application.new(data)
      when 'cartridges'
        carts = Array.new
        data.each do |cart_json|
          carts.push(Cartridge.new(cart_json))
        end
        return carts
      when 'cartridge'
        return Cartridge.new(data)
      when 'user'
        return User.new(data)
      when 'keys'
        keys = Array.new
        data.each do |key_json|
          keys.push(Key.new(key_json))
        end
        return keys
      when 'key'
        return Key.new(data)
      else
      data
      end
    end

    def request(request, retries=0)
      response = nil
      begin
        response = request.execute
        #set cookie
        rh_sso = response.cookies['rh_sso']
        if not rh_sso.nil?
          @@headers["cookie"] = "rh_sso=#{rh_sso}"
        end
      rescue RestClient::RequestTimeout, RestClient::ServerBrokeConnection => e
        # if it is a get request then re-try
        if retries>0
          sleep 5*retries
          return request(request, retries-1)
        else
          raise ConnectionException.new("Connection to server timed out or got interrupted: #{e.message}")
        end
      rescue RestClient::ExceptionWithResponse => e
        process_error_response(e.response)
      rescue Exception => e
        raise ResourceAccessException.new("Failed to access resource: #{e.message}")
      end
      return parse_response(response) unless response.nil? or response.code == 204
    end

    def process_error_response(response)
      messages = Array.new
      begin
        result = RHC::Json.decode(response)
        messages = result['messages']
      rescue Exception => e
        logger.debug "Response did not include a message from server" if @mydebug
        #puts response
      end
      case response.code
      when 401
        raise UnAuthorizedException.new("Not authenticated")
      when 403
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise RequestDeniedException.new(message['text'])
          end
        end
      when 404
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ResourceNotFoundException.new(message['text'])
          end
        end
      when 409
        messages.each do |message|
          if message['severity'] and message['severity'].upcase == "ERROR"
            raise ValidationException.new(message['text'])
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
            raise ClientErrorException.new(message['text'])
          end
        end
      when 500
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ServerErrorException.new(message['text'])
          end
        end
      when 503
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ServiceUnavailableException.new(message['text'])
          end
        end
      else
        raise ResourceAccessException.new("Server returned error code with no output: #{response.code}")
      end

    end
  end
end
