module RHC
  module ContextHelpers
    def app_context
      debug "Getting app context"
      get_uuid_cmd = "git config --get rhc.app-uuid"
      debug "Running #{get_uuid_cmd}"
      uuid = %x[#{get_uuid_cmd}].strip
      debug "UUID = '#{uuid}'"
      return nil if $?.exitstatus != 0 or uuid.empty?

      # proof of concept - we shouldn't be traversing
      # the broker should expose apis for getting the application via a uuid
      rest_client.domains.each do |rest_domain|
        rest_domain.applications.each do |rest_app|
          return rest_app.name if rest_app.uuid == uuid
        end
      end

      debug "Couldn't find app with UUID == #{uuid}"
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
