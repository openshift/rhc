module RHC::Commands
  class Authorization < Base

    summary "Show the authorization tokens for your account"
    description <<-DESC
      Shows the full list of authorization tokens on your account. You 
      can add, edit, or delete authorizations with subcommands.

      An authorization token grants access to the OpenShift REST API with
      a set of privileges called 'scopes' for a limited time.  You can
      add an optional note to each authorization token to assist you in
      remembering what is available.
      DESC
    alias_action 'authorizations', :root_command => true
    default_action :list
    def list
      rest_client.authorizations.each{ |auth| paragraph{ display_authorization(auth, token_for_user) } } or info "No authorizations"

      0
    end

    option "--scopes SCOPES", "A comma delimited list of scopes (e.g. 'scope1,scope2')"
    option "--note NOTE", "A description of this authorization (optional)"
    option "--expires-in SECONDS", "The number of seconds before this authorization expires (optional)"
    summary "Add an authorization to your account"
    syntax "--scopes SCOPES [--note NOTE] [--expires-in SECONDS]"
    description <<-DESC
      Add an authorization to your account. An authorization token grants
      access to the OpenShift REST API with a set of privileges called 'scopes'
      for a limited time.  You can add an optional note to each authorization
      token to assist you in remembering what is available.

      To view the list of scopes supported by this server, run this command
      without any options.

      You may pass multiple scopes to the --scopes option inside of double
      quotes (--scopes \"scope1 scope2\") or by separating them with commas
      (--scopes scope1,scope2).

      The server will enforce a maximum and default expiration that may
      differ for each scope. If you request an expiration longer than the
      server maximum, you will be given the default value.
      DESC
    def add
      unless options.scopes.to_s.strip.present?
        say "When adding an authorization, you must specify which permissions clients will have."
        scope_help
        say "Run 'rhc authorization add --help' to see more options"
        return 0
      end

      say "Adding authorization ... "
      auth = rest_client.add_authorization(:scope => options.scopes, :note => options.note, :expires_in => options.expires_in)
      success "done"
      paragraph{ display_authorization(auth) }

      0
    end

    summary "Delete one or more authorization tokens"
    syntax "<token_or_id> [...<token_or_id>]"
    description <<-DESC
      Delete one or more of the authorization tokens associated with 
      your account. After deletion, any clients using the token will
      no longer have access to OpenShift and will need to reauthenticate.
      DESC
    argument :auth_token, "The token you wish to delete", ['--auth-token TOKEN'], :type => :list
    def delete(tokens)
      raise ArgumentError, "You must specify one or more tokens to delete" if tokens.blank?
      say "Deleting authorization ... "
      tokens.each{ |token| rest_client.delete_authorization(token) }
      success "done"
      0
    end

    summary "Delete all authorization tokens from your account"
    description <<-DESC
      Delete all the authorization tokens associated with your account.
      After deletion, any clients using those tokens will need to
      reauthenticate.
      DESC
    def delete_all
      say "Deleting all authorizations ... "
      rest_client.delete_authorizations
      success "done"
      0
    end

    protected
      def scope_help
        descriptions = rest_client.authorization_scope_list
        paragraph{ say table(descriptions, :header => ['Scope', 'Description']) }
        paragraph{ say "You may pass multiple scopes to the --scopes option inside of double quotes (--scopes \"scope1 scope2\") or by separating them with commas (--scopes scope1,scope2)." }
      end
  end
end
