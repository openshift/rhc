module RHC::Commands
  class Account < Base
    suppress_wizard

    summary "Display details about your OpenShift account"
    description <<-DESC
      Shows who you are logged in to the server as and the capabilities
      available to you on this server.

      To access more details about your account please visit the website.
      DESC
    def run
      user = rest_client.user

      say_table nil, get_properties(user, :login, :plan_id, :consumed_gears, :max_gears) + get_properties(user.capabilities, :gear_sizes).unshift(['Server', openshift_server]), :delete => true

      if openshift_online_server?
      else
      end

      0
    end

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
    alias_action 'logout', :root_command => true
    def logout
      if options.all
        rest_client.user # force authentication
        say "Deleting all authorizations associated with your account ... "
        rest_client.delete_authorizations
        success "done"
      elsif options.token
        options.noprompt = true
        say "Ending session on server ... "
        begin
          rest_client.delete_authorization(options.token)
          success "deleted"
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
