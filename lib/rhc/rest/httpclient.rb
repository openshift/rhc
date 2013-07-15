module RHC
  module Rest
    #
    # An instance of HTTPClient that will support deferred
    # Basic credentials and allow token challenges.
    #
    class HTTPClient < ::HTTPClient
      def initialize(*args)
        super
        @www_auth = WWWAuth.new
        @request_filter = [proxy_auth, www_auth]
      end
    end

    #
    # Support three altered authentication behaviors
    #
    # * Allow a bearer token to be provided for a server
    # * Allow the user and password attributes to be lazily
    #   evaluated when the credentials are needed, rather than
    #   up front.
    # * If a BASIC auth request has been rejected, do not
    #   retry.
    #
    class WWWAuth < HTTPClient::WWWAuth
      attr_reader :oauth2
      def initialize
        super
        @oauth2 = OAuth2.new
        @authenticator.unshift(@oauth2)

        deferred = DeferredBasic.new
        @authenticator.map!{ |o| o == @basic_auth ? deferred : o }
        @basic_auth = deferred
      end

      class OAuth2
        include ::HTTPClient::Util
        attr_reader :scheme

        def initialize
          @cred = nil
          @auth = {}
          @set = false
          @scheme = "Bearer"
        end

        def reset_challenge
        end

        def set(uri, user, password)
          @set = true
          if uri.nil?
            @cred = password
          else
            @auth[urify(uri)] = password
          end
        end

        def set_token(uri, token)
          set(uri, nil, token)
        end

        def set?
          @set == true
        end

        def get(req)
          target_uri = req.header.request_uri
          return @cred if @cred
          hash_find_value(@auth) { |uri, cred|
            uri_part_of(target_uri, uri)
          }
        end

        def challenge(uri, param_str = nil)
          false
        end
      end

      class DeferredCredential
        def initialize(user, password)
          @user, @password = user, password
        end
        def user
          (@user.call if @user.respond_to?(:call)) or @user
        end
        def passwd
          (@password.call if @password.respond_to?(:call)) or @password
        end

        #
        # Pretend to be a string
        #
        def to_str
          ["#{user}:#{passwd}"].pack('m').tr("\n", '')
        end
        [:sub].each do |sym| 
          define_method(sym) { |*args|; to_str.send(sym, *args); }
        end
      end

      class DeferredBasic < ::HTTPClient::BasicAuth
        # Set authentication credential.
        # uri == nil for generic purpose (allow to use user/password for any URL).
        def set(uri, user, passwd)
          @set = true
          if uri.nil?
            @cred = DeferredCredential.new(user, passwd)
          else
            uri = uri_dirname(urify(uri))
            @auth[uri] = DeferredCredential.new(user, passwd)
          end
        end
        def challenge(uri, param_str = nil)
          return false if caller.any?{ |s| s =~ /webmock.*httpclient_adapter.*build_request_signature/ }
          uri = urify(uri)
          challenged = @challengeable[uri]
          @challengeable[uri] = true
          !challenged
        end            
      end
    end
  end
end