require 'rhc/git_helpers'

module RHC
  #
  # Methods in this module should not attempt to read from the options hash
  # in a recursive manner (server_context can't read options.server).
  #
  module ContextHelpers
    include RHC::GitHelpers

    def server_context
      ENV['LIBRA_SERVER'] || (!options.clean && config['libra_server']) || "openshift.redhat.com"
    end

    def token_context
      token_store.get(options.rhlogin, options.server) if options.rhlogin
    end

    def app_context
      debug "Getting app context"

      name = git_config_get "rhc.app-name"
      return name if name.present?

      uuid = git_config_get "rhc.app-uuid"

      if uuid.present?
        # proof of concept - we shouldn't be traversing
        # the broker should expose apis for getting the application via a uuid
        rest_client.domains.each do |rest_domain|
          rest_domain.applications.each do |rest_app|
            return rest_app.name if rest_app.uuid == uuid
          end
        end

        debug "Couldn't find app with UUID == #{uuid}"
      end
      nil
    end

    def namespace_context
      # right now we don't have any logic since we only support one domain
      # TODO: add domain lookup based on uuid
      domain = rest_client.domains.first
      raise RHC::DomainNotFoundException, "No domains configured for this user.  You may create one using 'rhc domain create'." if domain.nil?

      domain.id
    end
  end
end
