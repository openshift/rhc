module RHC::Auth
  class Basic
    attr_reader :cookie

    def initialize(*args)
      if args[0].is_a?(String) or args.length > 1
        @username, @password = args
      else
        @options = args[0] || Commander::Command::Options.new
        @username = options.rhlogin
        @password = options.password
      end
    end

    def to_request(request)
      (request[:cookies] ||= {})[:rh_sso] = cookie if cookie
      request[:user] ||= username || (request[:lazy_auth] != true && ask_username)
      request[:password] ||= password || (username? && request[:lazy_auth] != true && ask_password)
      request
    end

    def retry_auth?(response)
      if response.code == 401
        @cookie = nil
        ask_username unless username?
        error "Username or password is not correct" if password
        ask_password
        true
      else
        @cookie ||= response.cookies['rh_sso']
        false
      end
    end

    protected
      include RHC::Helpers
      attr_reader :options, :username, :password

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
