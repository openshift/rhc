require 'rhc/commands/base'

module RHC::Commands
  class Domain < Base
    summary "Add or rename the container for your apps"
    syntax "<action>"
    description <<-DESC
      OpenShift groups applications within a domain.  Each domain has a namespace value
      that will be used as part of the public URL for an application.

      For example, when creating a domain with the namespace "test", any applications 
      created in that domain will have the public URL:

        http://<appname>-test.rhcloud.com

      Today, each account may have a single domain.
      DESC
    default_action :show

    summary "Define a namespace for your applications to share."
    syntax "<namespace>"
    argument :namespace, "Namespace for your application(s) (alphanumeric)", ["-n", "--namespace NAME"]
    def create(namespace)
      paragraph { say "Creating domain with namespace '#{namespace}'" }
      rest_client.add_domain(namespace)

      results do
        say "Success!"
        say "You may now create an application using the 'rhc create-app' command"
      end

      0
    end

    summary "Change current namespace (will change application urls)"
    syntax "<old namespace> <new namespace>"
    argument :old_namespace, "Old namespace to change", []
    argument :new_namespace, "New namespace to change", ["-n", "--namespace NAME"]
    alias_action :alter, :deprecated => true
    def update(old_namespace, new_namespace)
      domain = rest_client.find_domain(old_namespace)

      say "Changing namespace '#{domain.id}' to '#{new_namespace}' ... "

      domain.update(new_namespace)

      success "success"
      info "Applications in this domain will use the new namespace in their URL."

      0
    end

    summary "Display your domain and any applications"
    def show
      domain = rest_client.domains.first

      warn "In order to deploy applications, you must create a domain with 'rhc setup' or 'rhc create-domain'." and return 1 unless domain

      applications = domain.applications(:include => :cartridges)

      if applications.present?
        header "Applications in #{domain.id} domain" do
          applications.each do |a|
            display_app(a,a.cartridges)
          end
        end
        success "You have #{applications.length} applications in your domain."
      else
        success "The domain #{domain.id} exists but has no applications. You can use 'rhc create-app' to create a new application."
      end

      0
    end

    summary "DEPRECATED use 'setup' instead"
    deprecated 'rhc setup'
    # :nocov:
    def status
      1 # return error status
    end
    # :nocov:

    summary "Deletes your domain."
    syntax "<namespace>"
    argument :namespace, "Namespace you wish to destroy", ["-n", "--namespace NAME"]
    alias_action :destroy, :deprecated => true
    def delete(namespace)
      domain = rest_client.find_domain namespace

      say "Deleting domain '#{namespace}' ... "

      begin
        domain.destroy
      rescue RHC::Rest::ClientErrorException #FIXME: I am insufficiently specific
        raise RHC::Exception.new("Your domain contains applications. Delete applications first.", 128)
      end

      success "deleted"
      
      0
    end
  end

end
