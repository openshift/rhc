module RHC::Auth
  class Basic
    attr_reader :cookie

    def initialize(*args)
      if args[0].is_a?(String)
        @username, @password = args
      else
        @config = args[0] || RHC::Config.default
        @options = config.instance_variable_get(:@opts) # clean this up
        @username = config.username
        @password = config.password
      end
    end

    def to_request(request)
      (request[:cookies] ||= {})[:rh_sso] = cookie if cookie
      request[:user] ||= username
      request[:password] ||= password || (username? && ask_password)
      request
    end

    def retry_auth?(response)
      if response.code == 401
        ask_username unless username?
        error "Username or password is not correct" if password
        ask_password
        true
      else
        @cookie ||= response.cookies['rh_sso']
      end
    end

    protected
      include RHC::Helpers
      attr_reader :config, :options, :username, :password

      def ask_username
        @username = ask("Login to #{openshift_server}: ")
      end
      def ask_password
        @password = ask("Password: ") { |q| q.echo = '*' }
      end

      def username?
        username.present?
      end
  end
end
