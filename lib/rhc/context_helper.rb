module RHC
  module ContextHelpers
    def app_context
      # We currently do not have a way of determening an app context so return nil
      # In the future we will use the uuid embeded in the git config to query
      # the server for the repo's app name
      nil
    end

    def namespace_context
      # right now we don't have any logic since we only support one domain
      # :nocov: remove nocov when cart tests go back in
      domain = rest_client.domains[0]
      raise RHC::DomainNotFoundException, "No domains configured for this user.  You may create one using 'rhc domain create'." if domain.nil?

      domain.id
    end
  end
end
