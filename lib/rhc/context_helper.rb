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
        def self.takes_domain(opts={})
          if opts[:argument]
            argument :namespace, "Name of a domain", ["-n", "--namespace NAME"], :allow_nil => true, :default => :from_local_git
          else
            option ["-n", "--namespace NAME"], "Name of a domain", :default => :from_local_git
          end
        end
        # Does not take defaults to avoid conflicts
        def self.takes_application_or_domain(opts={})
          option ["-n", "--namespace NAME"], "Name of a domain"
          option ["-a", "--app NAME"], "Name of an application"
          if opts[:argument]
            argument :target, "The name of a domain, or an application name with domain (domain or domain/application)", ["-t", "--target NAME_OR_PATH"], :allow_nil => true, :covered_by => [:application_id, :namespace, :app]
          end
        end
        def self.takes_application(opts={})
          if opts[:argument]
            argument :app, "Name of an application", ["-a", "--app NAME"], :allow_nil => true, :default => :from_local_git, :covered_by => :application_id
          else
            option ["-a", "--app NAME"], "Name of an application", :default => :from_local_git, :covered_by => :application_id
          end
          option ["-n", "--namespace NAME"], "Name of a domain", :default => :from_local_git
          option ["--application-id ID"], "ID of an application", :hide => true, :default => :from_local_git, :covered_by => :app
        end
      end
    end

    def find_domain(opts={})
      domain = options.namespace || options.target || namespace_context
      if domain
        rest_client.find_domain(domain)
      else
        raise ArgumentError, "You must specify a domain with -n."
      end
    end

    def find_app_or_domain(opts={})
      domain, app =
        if options.target.present?
          options.target.split(/\//)
        elsif options.namespace || options.app
          if options.app =~ /\//
            options.app.split(/\//)
          else
            [options.namespace || namespace_context, options.app]
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

    def find_app(opts={})
      if id = options.application_id.presence
        if opts.delete(:with_gear_groups)
          return rest_client.find_application_by_id_gear_groups(id, opts)
        else
          return rest_client.find_application_by_id(id, opts)
        end
      end
      domain, app =
        if options.app
          if options.app =~ /\//
            options.app.split(/\//)
          else
            [options.namespace || namespace_context, options.app]
          end
        end
      if app.present? && domain.present?
        if opts.delete(:with_gear_groups)
          rest_client.find_application_gear_groups(domain, app, opts)
        else
          rest_client.find_application(domain, app, opts)
        end
      else
        raise ArgumentError, "You must specify an application with -a, or run this command from within Git directory cloned from OpenShift."
      end
    end

    def server_context(defaults=nil, arg=nil)
      value = ENV['LIBRA_SERVER'] || (!options.clean && config['libra_server']) || "openshift.redhat.com"
      defaults[arg] = value if defaults && arg
      value
    end

    def from_local_git(defaults, arg)
      @local_git_config ||= {
        :application_id => git_config_get('rhc.app-id').presence,
        :app => git_config_get('rhc.app-name').presence,
        :namespace => git_config_get('rhc.domain-name').presence,
      }
      defaults[arg] ||= @local_git_config[arg] unless @local_git_config[arg].nil?
      @local_git_config
    end

    def namespace_context
      # right now we don't have any logic since we only support one domain
      # TODO: add domain lookup based on uuid
      domain = rest_client.domains.first
      raise RHC::NoDomainsForUser if domain.nil?

      domain.name
    end
  end
end
