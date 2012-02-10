require 'rubygems'
require 'rest-client'
require 'logger'
require 'json'

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
          domains.push(Rhc::Rest::Domain.new(domain_json))
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
      end
    end

    def send(request)
      puts "sending request"
      begin
        begin
          puts "sending request"
          response = request.execute
          puts "#{response}"
          return parse_response(response) unless response.nil? or response.code == :no_content
        rescue RestClient::ExceptionWithResponse => e
          process_error_response(e.response)
        end
      rescue Exception => e
        puts e.message
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
          puts "ResourceNotFound  #{message['text'] }"
        end
        puts "ResourceNotFound Routing error"
      when 422
        messages.each do |message|
          puts "ValidationException  #{message['text'] }"
        end
      when 400
        puts "ClientErrorException"
      when 500
        puts "ServerErrorException"
      when 503
        puts "ServiceUnavailableException"
      end

    end
  end
end
