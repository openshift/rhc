module RHC::Auth
  class Token
    def initialize(opt, auth=nil, store=nil)
      if opt.is_a?(String)
        @token = opt
      else
        @options = opt || Commander::Command::Options.new
        @token = options[:token]
        @no_interactive = options[:noprompt]
      end
      @auth = auth
      @store = store
      read_token
    end

    def to_request(request)
      if token
        (request[:headers] ||= {})['authorization'] = "Bearer #{token}"
      elsif auth
        auth.to_request(request)
      end
      request
    end

    def retry_auth?(response, client)
      if response.status == 401
        token_rejected(response, client)
      else
        false
      end
    end

    def username
      auth && auth.respond_to?(:username) && auth.username || options[:username]
    end

    def save(token)
      store.put(username, openshift_server, token) if store
      @token = token
    end

    def can_authenticate?
      token || auth && auth.can_authenticate?
    end

    protected
      include RHC::Helpers
      attr_reader :options, :token, :auth, :store

      def token_rejected(response, client)
        unless auth && auth.can_authenticate?
          if token
            raise RHC::Rest::TokenExpiredOrInvalid, "Your authorization token is expired or invalid."
          end
          @token = nil
          return false
        end
        if token && !@fetch_once && @no_interactive
          raise RHC::Rest::TokenExpiredOrInvalid, "Your authorization token is expired or invalid."
        end

        if token
          warn "Your session has expired. Please sign in to start a new session."
        else
          info "Please sign in to start a new session to #{openshift_server}."
        end
        @token = nil

        if auth_token = client.new_session(:auth => auth)
          @fetch_once = true
          save(auth_token.token)
          true
        else
          auth.retry_auth?(response, client)
        end
      end

      def read_token
        @token ||= store.get(username, openshift_server) if store
      end
  end
end
