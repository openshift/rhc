##

module RestClient
  class Request
    alias _initialize initialize
    
    attr_accessor :ssl_version
    
    def initialize(args)
      _initialize args
      @ssl_version = args[:ssl_version] || 'SSLv3'
    end
    
    # this is an almost verbatim copy of the original RestClient::Request#transmit
    # https://github.com/archiloque/rest-client/blob/300ce6876715661cd32db384376f9ee33a97d237/lib/restclient/request.rb
    # the edit is to call Net::HTTP#ssl_version on net, a la https://github.com/archiloque/rest-client/pull/123
    # :nocov:
    def transmit uri, req, payload, & block
      setup_credentials req

      net = net_http_class.new(uri.host, uri.port)
      net.use_ssl = uri.is_a?(URI::HTTPS)
      # MRI 1.8.7 shipped with a version of Net::HTTP that doesn't have #ssl_version=
      net.ssl_version = @ssl_version if @ssl_version and net.respond_to? :ssl_version=
      if (@verify_ssl == false) || (@verify_ssl == OpenSSL::SSL::VERIFY_NONE)
        net.verify_mode = OpenSSL::SSL::VERIFY_NONE
      elsif @verify_ssl.is_a? Integer
        net.verify_mode = @verify_ssl
        net.verify_callback = lambda do |preverify_ok, ssl_context|
          if (!preverify_ok) || ssl_context.error != 0
            err_msg = "SSL Verification failed -- Preverify: #{preverify_ok}, Error: #{ssl_context.error_string} (#{ssl_context.error})"
            raise SSLCertificateNotVerified.new(err_msg)
          end
          true
        end
      end
      net.cert = @ssl_client_cert if @ssl_client_cert
      net.key = @ssl_client_key if @ssl_client_key
      net.ca_file = @ssl_ca_file if @ssl_ca_file
      net.read_timeout = @timeout if @timeout
      net.open_timeout = @open_timeout if @open_timeout

      # disable the timeout if the timeout value is -1
      net.read_timeout = nil if @timeout == -1
      net.out_timeout = nil if @open_timeout == -1

      RestClient.before_execution_procs.each do |before_proc|
        before_proc.call(req, args)
      end

      log_request

      net.start do |http|
        if @block_response
          http.request(req, payload ? payload.to_s : nil, & @block_response)
        else
          res = http.request(req, payload ? payload.to_s : nil) { |http_response| fetch_body(http_response) }
          log_response res
          process_result res, & block
        end
      end
    rescue EOFError
      raise RestClient::ServerBrokeConnection
    rescue Timeout::Error
      raise RestClient::RequestTimeout
    end
    
  end
end