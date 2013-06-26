module RHC::Auth
  class Negotiate < Basic
    def initialize(*args)
      @options = args[0] || Commander::Command::Options.new
      @no_interactive = options[:noprompt]
    end

    def to_request(request)
      request[:user] = nil
      request[:password] = nil
      request
    end

    def retry_auth?(response, client)
      false
    end

    def can_authenticate?
      true
    end
  end
end
