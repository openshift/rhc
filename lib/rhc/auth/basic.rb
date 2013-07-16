module RHC::Auth
  class Basic
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
      request[:user] ||=
        lambda{ username || (request[:lazy_auth] != true && ask_username) || nil }
      request[:password] ||=
        lambda{ password || (username? && request[:lazy_auth] != true && ask_password) || nil }
      request
    end

    def retry_auth?(response, client)
      if response.status == 401
        credentials_rejected
      else
        false
      end
    end

    def can_authenticate?
      username? and not (password.nil? and @skip_interactive and @no_interactive)
    end

    attr_reader :username

    protected
      include RHC::Helpers
      attr_reader :options, :password

      def credentials_rejected
        error "Username or password is not correct" if username? && password
        unless @skip_interactive or @no_interactive
          ask_username unless username?
          ask_password
          true
        end
      end

      def ask_username
        @username = ask("Login to #{openshift_server}: ") unless @no_interactive
      end
      def ask_password
        @password = ask("Password: ") { |q|
          q.echo = '*'
          q.whitespace = :chomp
        } unless @no_interactive
      end

      def username?
        username.present?
      end
  end
end
