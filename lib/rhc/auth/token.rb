module RHC::Auth
  class Token
    def initialize(opt, auth=nil, store=nil)
      if opt.is_a?(String)
        @token = opt
      else
        @options = opt || Commander::Command::Options.new
        @token = options[:token]
        @no_interactive = options[:noprompt]
        @allows_tokens = options[:use_authorization_tokens]
      end
      @auth = auth
      @store = store
      read_token
    end

    def to_request(request)
      if auth and !token and (!@allows_tokens or @can_get_token == false)
        debug "Bypassing token auth"
        auth.to_request(request)
      else
        # If no token is available an empty one will be submitted at this
        # point.  This is actually required in order for the retry logic to be
        # triggered in all cases.
        #
        # Previously a request with no authentication was submitted to trigger
        # this behavior but it was found not to work in certain scenarios where
        # Broker authentication is handled by Apache.  In those cases a 403 is
        # returned and not secondary authentication attempt is made.
        debug "Using token authentication"
        (request[:headers] ||= {})['authorization'] = "Bearer #{token}"
      end
      request
    end

    def retry_auth?(response, client)
      case response.status
      when 401
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
        has_token = !!token
        @token = nil

        unless auth && auth.can_authenticate?
          if has_token
            raise RHC::Rest::TokenExpiredOrInvalid, "Your authorization token is expired or invalid."
          end
          debug "Cannot authenticate via token or password, exiting"
          return false
        end

        if has_token
          if cannot_retry?
            raise RHC::Rest::TokenExpiredOrInvalid, "Your authorization token is expired or invalid."
          end
          if not client.supports_sessions?
            raise RHC::Rest::AuthorizationsNotSupported
          end
        end

        @can_get_token = client.supports_sessions? && @allows_tokens

        if has_token
          warn auth.expired_token_message
        elsif @can_get_token
          info auth.get_token_message
        end

        return auth.retry_auth?(response, client) unless @can_get_token

        debug "Creating a new authorization token"
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

      def cannot_retry?
        !@fetch_once && @no_interactive
      end
  end
end
