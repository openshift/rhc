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

    def to_request(request, client=nil)
      if !token and auth and @allows_tokens and client and client.supports_sessions?
        debug "Attempting to generate token"
        token_rejected(nil, client)
      end

      if token
        debug "Using token authentication"
        (request[:headers] ||= {})['authorization'] = "Bearer #{token}"
      elsif auth
        debug "Bypassing token auth"
        auth.to_request(request, client)
      end
      request
    end

    def retry_auth?(response, client)
      if response && response.status != 401
        false
      else
        token_rejected(response, client)
      end
    end

    def username
      auth && auth.respond_to?(:username) && auth.username || options[:username]
    end

    def token_store_user_key
      auth && auth.respond_to?(:token_store_user_key) && auth.token_store_user_key || username
    end

    def save(token)
      store.put(token_store_user_key, openshift_server, token) if store
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
        @token ||= store.get(token_store_user_key, openshift_server) if store
      end

      def cannot_retry?
        !@fetch_once && @no_interactive
      end
  end
end
