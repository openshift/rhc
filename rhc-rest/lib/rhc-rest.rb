require 'rubygems'
require 'rest-client'
require 'logger'
require 'json'

require File.dirname(__FILE__) + '/rhc-rest/exceptions/exceptions.rb'
require File.dirname(__FILE__) + '/rhc-rest/application'
require File.dirname(__FILE__) + '/rhc-rest/cartridge'
require File.dirname(__FILE__) + '/rhc-rest/client'
require File.dirname(__FILE__) + '/rhc-rest/domain'
require File.dirname(__FILE__) + '/rhc-rest/key'
require File.dirname(__FILE__) + '/rhc-rest/user'

@@end_point = ""
@@headers = {:accept => :json}
module Rhc
  module Rest
    def logger
      logger.new(STDOUT)
    end

    def parse_response(response)
      result = JSON.parse(response)
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

    def send(request)
      begin
        begin
          response = request.execute
          #puts "#{response}"
          return parse_response(response) unless response.nil? or response.code == 204
        rescue RestClient::ExceptionWithResponse => e
          process_error_response(e.response)
        end
      rescue Exception => e
        raise ResourceAccessException.new("Failed to access resource: #{e.message}")
      end
    end

    def process_error_response(response)
      messages = Array.new
      begin
        result = JSON.parse(response)
        messages = result['messages']
      rescue Exception => e
      end
      case response.code
      when 404
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ResourceNotFoundException.new(message['text'])
          end
        end
      when 422
        messages.each do |message|
          messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ValidationException.new(message['text'])
          end
        end
        end
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
      end

    end
  end
end
