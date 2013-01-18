module RHC::Auth
  class Basic
    attr_reader :cookie

    def initialize(*args)
      if args[0].is_a?(String) or args.length > 1
        @username, @password = args
      else
        @options = args[0] || Commander::Command::Options.new
        @username = options[:rhlogin]
        @password = options[:password]
        @no_interactive = options[:noprompt]
      end
      @skip_interactive = !@password.nil?
    end

    def to_request(request)
      (request[:cookies] ||= {})[:rh_sso] = cookie if cookie
      request[:user] ||= username || (request[:lazy_auth] != true && ask_username) || nil
      request[:password] ||= password || (username? && request[:lazy_auth] != true && ask_password) || nil
      request
    end

    def retry_auth?(response)
      if response.status == 401
        @cookie = nil
        error "Username or password is not correct" if username? && password
        unless @skip_interactive or @no_interactive
          ask_username unless username?
          ask_password
          true
        end
      else
        @cookie ||= Array(response.cookies).inject(nil){ |v, c| c.name == 'rh_sso' ? c.value : v }
        false
      end
    end

    protected
      include RHC::Helpers
      attr_reader :options, :username, :password

      def ask_username
        @username = ask("Login to #{openshift_server}: ") unless @no_interactive
      end
      def ask_password
        @password = ask("Password: ") { |q| q.echo = '*' } unless @no_interactive
      end

      def username?
        username.present?
      end
  end
end
