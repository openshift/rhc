require 'uri'
require 'net/https'
require 'ostruct'

module RHCHelper
  module Httpify
    include Loggable

    # attributes that contain statistics based on calls to connect
    attr_accessor :response_code, :response_time

    def http_instance(uri, timeout=30)
      proxy = ENV['http_proxy'] ? URI.parse(ENV['http_proxy']) : OpenStruct.new
      http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port)
      http.open_timeout = timeout
      http.read_timeout = timeout
      if (uri.scheme == "https")
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      return http.start
    end

    def http_get(url, timeout=30)
      uri = URI.parse(url)
      http = http_instance(uri, timeout)
      request = Net::HTTP::Get.new(uri.request_uri)
      http.request(request)
    end
    
    def http_head(url, host=nil, follow_redirects=true)
      uri = URI.parse(url)
      http = http_instance(uri)
      request = Net::HTTP::Head.new(uri.request_uri)
      request["Host"] = host if host
      response = http.request(request)
      
      if follow_redirects and response.is_a?(Net::HTTPRedirection)
        return http_head(response.header['location'])
      else
        return response
      end
    end

    def is_inaccessible?(max_retries=120)
      max_retries.times do |i|
        begin
          if http_head("http://#{hostname}").is_a? Net::HTTPServerError
            return true
          else
            logger.info("Connection still accessible / retry #{i} / #{hostname}")
            sleep 1
          end
        rescue
          return true
        end
      end
      return false
    end

    def is_accessible?(use_https=false, max_retries=120, host=nil)
      prefix = use_https ? "https://" : "http://"
      url = prefix + hostname

      max_retries.times do |i|
        begin
          if http_head(url, host).is_a? Net::HTTPSuccess
            return true
          else
            logger.info("Connection still inaccessible / retry #{i} / #{url}")
            sleep 1
          end
        rescue SocketError
          logger.info("Connection still inaccessible / retry #{i} / #{url}")
          sleep 1
        end
      end

      return false
    end

    def doesnt_exist?
      response = do_http({
        :method => :head,
        :url => "http://#{hostname}",
        :expected => SocketError
      })

      return !(response.is_a?(Net::HTTPSuccess))
    end

    def connect(use_https=false, max_retries=30)
      prefix = use_https ? "https://" : "http://"
      url = prefix + hostname

      logger.info("Connecting to #{url}")
      beginning_time = Time.now

      max_retries.times do |i|
        response = http_get(url, 1)

        if response.is_a? Net::HTTPSuccess
          @response_code = response.code
          @response_time = Time.now - beginning_time
          logger.info("Connection result = #{@response_code} / #{url}")
          logger.info("Connection response time = #{@response_time} / #{url}")
          return response.body
        else
          logger.info("Connection failed / retry #{i} / #{url}")
          sleep 1
        end
      end

      return nil
    end
  end
end
