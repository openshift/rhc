require 'rhc/commands/base'

module RHC::Commands
  class Domain < Base
    summary "Add or rename the container for your apps"
    syntax "<action>"
    description <<-DESC
      All OpenShift applications must belong to a domain.  The name of the domain
      will be used as part of the public URL for an application.

      For example, when creating a domain with the name "test", any applications
      created in that domain will have the public URL:

        http://<appname>-test.rhcloud.com

      Each account may have access to one or more domains shared by others.  Depending
      on your plan or configuration, you may be able to create more than one domain.

      To create your first domain, run 'rhc setup' or 'rhc create-domain'.
      DESC
    default_action :help

    summary "Create a new container for applications."
    syntax "<namespace>"
    description <<-DESC
      A domain is a container for your applications. Each account may have one
      or more domains (depending on plan), and you may collaborate on applications
      by adding members to your domain.

      The name of the domain is called its "namespace", and becomes part of the
      application public URLs. For example, when creating a domain with the name "test",
      all applications in that domain will have the public URL:

        http://<appname>-test.rhcloud.com

      The domain owner may limit the gear sizes available to applications by using the
      '--allowed-gear-sizes' option.  If '--no-allowed-gear-sizes' is set, no applications
      can be created in the domain.  Older servers may not support this option.
      DESC
    option ['--no-allowed-gear-sizes'], 'Do not allow any gear sizes in this domain.', :optional => true
    option ['--allowed-gear-sizes [SIZES]'], 'A comma-delimited list of the gear sizes that will be allowed in this domain.', :optional => true
    argument :namespace, "New domain name (letters and numbers, max 16 chars)", ["-n", "--namespace NAME"]
    def create(namespace)
      say "Creating domain '#{namespace}' ... "
      rest_client.add_domain(namespace, :allowed_gear_sizes => check_allowed_gear_sizes)
      success "done"

      info "You may now create an application using the 'rhc create-app' command"

      0
    end

    summary "Rename a domain (will change application urls)"
    syntax "<old name> <new name>"
    argument :old_namespace, "Existing domain name", []
    argument :new_namespace, "New domain name (letters and numbers, max 16 chars)", ["-n", "--namespace NAME"]
    alias_action :update, :deprecated => true
    def rename(old_namespace, new_namespace)
      domain = rest_client.find_domain(old_namespace)

      say "Renaming domain '#{domain.name}' to '#{new_namespace}' ... "
      domain.rename(new_namespace)
      success "done"

      info "Applications in this domain will use the new name in their URL."

      0
    end

    summary "Change one or more configuration settings on the domain"
    syntax "<namespace>"
    option ['--no-allowed-gear-sizes'], 'Do not allow any gear sizes in this domain.', :optional => true
    option ['--allowed-gear-sizes [SIZES]'], "A comma-delimited list of gear sizes allowed in this domain. To see available sizes, run 'rhc account'.", :optional => true
    takes_domain :argument => true
    def configure(_)
      domain = find_domain
      payload = {}
      payload[:allowed_gear_sizes] = check_allowed_gear_sizes unless options.allowed_gear_sizes.nil? and options.no_allowed_gear_sizes.nil?

      if payload.present?
        say "Updating domain configuration ... "
        domain.configure(payload)
        success "done"
      end

      paragraph do
        say format_table("Domain #{domain.name} configuration", get_properties(domain, :allowed_gear_sizes), :delete => true)
      end

      0
    end

    summary "Display a domain and its applications"
    takes_domain :argument => true
    def show(_)
      domain = find_domain

      warn "In order to deploy applications, you must create a domain with 'rhc setup' or 'rhc create-domain'." and return 1 unless domain

      applications = domain.applications(:include => :cartridges)
      display_domain(domain, applications)

      if applications.present?
        success "You have #{pluralize(applications.length, 'application')} in your domain."
      else
        success "The domain #{domain.name} exists but has no applications. You can use 'rhc create-app' to create a new application."
      end

      0
    end

    summary "Display all domains you have access to"
    option ['--mine'], "Display only domains you own"
    option ['--ids'], "Display the unique id of the domain (not supported by all servers)"
    alias_action :domains, :root_command => true
    def list
      domains = rest_client.send(options.mine ? :owned_domains : :domains)

      warn "In order to deploy applications, you must create a domain with 'rhc setup' or 'rhc create-domain'." and return 1 unless domains.present?

      domains.each do |d|
        display_domain(d, nil, options.ids)
      end

      success "You have access to #{pluralize(domains.length, 'domain')}."

      0
    end

    summary "Delete a domain"
    syntax "<namespace>"
    takes_domain :argument => true
    option ["-f", "--force"], "Force the action"
    def delete(_)
      domain = find_domain

      say "Deleting domain '#{domain.name}' ... "
      domain.destroy(options.force.present?)
      success "deleted"

      0
    end

    summary "Leave a domain (remove your membership)"
    syntax "<namespace>"
    argument :namespace, "Name of the domain", ["-n", "--namespace NAME"]
    def leave(namespace)
      domain = rest_client.find_domain(namespace)

      say "Leaving domain ... "
      domain.leave
      success "done"

      0
    end

    protected
      def check_allowed_gear_sizes
        raise OptionParser::InvalidOption, "--allowed-gear-sizes and --no-allowed-gear-sizes cannot both be specified" unless options.allowed_gear_sizes.nil? or options.no_allowed_gear_sizes.nil?
        sizes = options.no_allowed_gear_sizes.nil? ? options.allowed_gear_sizes : false
        raise OptionParser::InvalidOption, "The server does not support --allowed-gear-sizes" unless sizes.nil? || rest_client.api.has_param?(:add_domain, 'allowed_gear_sizes')
        if sizes.is_a? String
          sizes.split(',').map(&:strip).map(&:presence)
        elsif sizes == false
          []
        elsif sizes
          raise OptionParser::InvalidOption, "Provide a comma delimited list of valid gear sizes to --allowed-gear-sizes"
        end
      end
  end
end
