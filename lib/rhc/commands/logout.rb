module RHC::Commands
  class Logout < Base
    suppress_wizard

    summary "End the current session"
    description <<-DESC
      Logout ends your current session on the server and then removes
      all of the local session files.  If you are using multiple 
      servers and configurations this will remove all of your local
      session files.

      The --all option will terminate all authorizations on your
      account. Any previously generated authorizations will be
      deleted and external tools that integrate with your account
      will no longer be able to log in.
      DESC
    option '--all', "Remove all authorizations on your account."
    alias_action 'account logout', :root_command => true
    def run
      if options.all
        rest_client.user # force authentication
        say "Deleting all authorizations associated with your account ... "
        begin
          rest_client.delete_authorizations
          success "done"
        rescue RHC::Rest::AuthorizationsNotSupported
          info "not supported"
        end
      elsif token_for_user
        options.noprompt = true
        say "Ending session on server ... "
        begin
          rest_client.delete_authorization(token_for_user)
          success "deleted"
        rescue RHC::Rest::AuthorizationsNotSupported
          info "not supported"
        rescue RHC::Rest::TokenExpiredOrInvalid
          info "already closed"
        rescue => e
          debug_error(e)
          warn e.message
        end
      end

      0
    ensure
      token_store.clear
      success "All local sessions removed."
    end
  end
end
