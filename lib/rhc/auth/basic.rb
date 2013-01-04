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
      request[:password] ||= password || (username? && request[:lazy_auth] != true && ask_password) || nil
      request
    end

    def retry_auth?(response)
      if response.status == 401
        @cookie = nil
        if username?
          error "Username or password is not correct" if password
        else
          ask_username
        end
        ask_password
        true
      else
        @cookie ||= Array(response.cookies).inject(nil){ |v, c| c.name == 'rh_sso' ? c.value : v }
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
