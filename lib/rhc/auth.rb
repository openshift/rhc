module RHC
  class Auth
    def initialize(server, config)
      @server = server
      @config = config
    end

    def to_headers
      
    end

    protected
      def username
        @username ||= config.username || ask("Login to #{openshift_server}: ")
      end
      def password
        @password ||= config.password || ask("Password: ") { |q| q.echo = '*' }
      end
  end
end
