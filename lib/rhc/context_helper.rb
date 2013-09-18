require 'rhc/git_helpers'

module RHC
  #
  # Methods in this module should not attempt to read from the options hash
  # in a recursive manner (server_context can't read options.server).
  #
  module ContextHelpers
    include RHC::GitHelpers

    def self.included(other)
      other.module_eval do
        def self.takes_application_or_domain(opts={})
          option ["-n", "--namespace NAME"], "Name of a domain"
          option ["-a", "--app NAME"], "Name of an application"
          if opts[:argument]
            argument :path, "The name of a domain, or an application name with domain (domain or domain/application)", ["-t", "--target NAME_OR_PATH"], :optional => true
          end
        end
      end
    end

    def find_app_or_domain(path=options.target)
      domain, app =
        if path.present?
          path.split(/\//)
        elsif options.namespace || options.app
          if options.app =~ /\//
            options.app.split(/\//)
          else
            [options.namespace || namespace_context, options.app || app_context]
          end
        end
      if app && domain
        rest_client.find_application(domain, app)
      elsif domain
        rest_client.find_domain(domain)
      else
        raise ArgumentError, "You must specify a domain with -n, or an application with -a."
      end
    end

    def find_app(path=options.to)
      domain, app =
        if path.present?
          if (parts = path.split(/\//)).length > 1
            parts
          else
            [options.namespace || namespace_context, path]
          end
        elsif options.namespace || options.app
          if options.app =~ /\//
            options.app.split(/\//)
          else
            [options.namespace || namespace_context, options.app || app_context]
          end
        end
      if app && domain
        rest_client.find_application(domain, app)
      else
        raise ArgumentError, "You must specify an application with -a."
      end
    end

    def server_context
      ENV['LIBRA_SERVER'] || (!options.clean && config['libra_server']) || "openshift.redhat.com"
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
      raise RHC::Rest::DomainNotFoundException, "No domains configured for this user.  You may create one using 'rhc create-domain'." if domain.nil?

      domain.id
    end
  end
end
