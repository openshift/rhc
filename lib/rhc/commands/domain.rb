require 'rhc/commands/base'

module RHC::Commands
  class Domain < Base
    summary "Manage the domain and namespace for your applications."
    syntax "<action>"
    default_action :show

    summary "Define a namespace for your applications to share."
    syntax "<namespace> [--timeout timeout]"
    argument :namespace, "Namespace for your application(s) (alphanumeric)", ["-n", "--namespace namespace"]
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    def create(namespace)
      paragraph { say "Creating domain with namespace '#{namespace}'" }
      rest_client.add_domain(namespace)

      results do
        say "Success!"
        say "You may now create an application using the 'rhc app create' command"
      end

      0
    end

    summary "Change current namespace (will change application urls)"
    syntax "<namespace> [--timeout timeout]"
    argument :namespace, "Namespace to change", ["-n", "--namespace namespace"]
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :alter
    def update(namespace)
      # TODO: Support multiple domains.  Right now we assume one domain so
      #       you don't have to send in the name of the domain you want to change
      #       but in the future this will be manditory if you have more than one
      #       domain.  Figure out how to support overloading of commands
      domain = rest_client.domains
      raise RHC::DomainNotFoundException, "No domains are registered to the user #{config.username}. Please use 'rhc domain create' to create one." if domain.empty?

      say "Changing namespace '#{domain[0].id}' to '#{namespace}'..."

      domain[0].update(namespace)

      results do
        say "Success!"
        say "You can use 'rhc domain show' to view any url changes.  Be sure to update any links including the url in your local git config: <local_git_repo>/.git/config"
      end

      0
    end

    summary "Display the applications in your domain"
    def show
      domain = rest_client.domains.first

      if domain
        paragraph do
          say "Applications in #{domain.id}:"
          apps = domain.applications
          if apps.length == 0
            say "No applications.  You can use 'rhc app create' to create new applications."
          else
            apps.each_with_index do |a,i|
              section(:top => (i == 0 ? 1 : 2)) do
                say_app_info(a)
              end
            end
          end
        end
      else
        say "No domain exists.  You can use 'rhc domain create' to create a namespace for applications." unless domain
      end
      0
    end

    summary "Run a status check on your domain"
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    def status
      args = []

      options.__hash__.each do |key, value|
        value = value.to_s
        if value.length > 0 && value.to_s.strip.length == 0; value = "'#{value}'" end
        args << "--#{key} #{value}"
      end

      Kernel.system("rhc-chk #{args.join(' ')} 2>&1")
      $?.exitstatus.nil? ? 1 : $?.exitstatus
    end

    summary "Deletes your domain."
    syntax "<namespace> [--timeout timeout]"
    argument :namespace, "Namespace you wish to destroy", ["-n", "--namespace namespace"]
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :destroy
    def delete(namespace)
      domain = rest_client.find_domain namespace

      say "Deleting domain '#{namespace}'"

      begin
        domain.destroy
      rescue RHC::Rest::ClientErrorException #FIXME: I am insufficiently specific
        raise RHC::Exception.new("Domain contains applications. Delete applications first.", 128)
      end

      results { say "Success!" }
      0
    end
  end

end
