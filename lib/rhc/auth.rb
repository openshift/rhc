module RHC
  class Auth
    attr_reader :cookie

    def initialize(config=RHC::Config.new)
      @config = config
      @options = config.instance_variable_get(:@opts) # clean this up
    end

    def to_request(request)
      (request[:cookies] ||= {})[:rh_sso] = cookie if cookie
      request[:user] ||= username
      request[:password] ||= password
      request
    end

    def retry_auth?(response)
      if response.code == 401
        ask_username unless username?
        error "Username or password is not correct" if password
        ask_password
        true
      else
        binding.pry
        @cookie ||= response.cookies['rh_sso']
      end
    end

    protected
      include RHC::Helpers
      attr_reader :config, :options

      def username
        @username ||= config.username
      end
      def password
        @password ||= config.password
      end
      def ask_username
        @username = ask("Login to #{openshift_server}: ")
      end
      def ask_password
        @password = ask("Password: ") { |q| q.echo = '*' }
      end

      def username?
        @username || config.username
      end
  end
end
