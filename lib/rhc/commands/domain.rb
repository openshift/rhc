require 'rhc/commands/base'

module RHC::Commands
  class Domain < Base
    summary "Manage your domain"
    syntax "<action>"
    default_action :show

    summary "Bind a registered user to a domain"
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

    summary "Update namespace (will change urls)."
    syntax "<namespace> [--timeout timeout]"
    argument :namespace, "Namespace for your application(s) (alphanumeric)", ["-n", "--namespace namespace"]
    option ["--timeout timeout"], "Timeout, in seconds, for the session"
    alias_action :alter
    def update(namespace)
      # TODO: Support multiple domains.  Right now we assume one domain so
      #       you don't have to send in the name of the domain you want to change
      #       but in the future this will be manditory if you have more than one
      #       domain.  Figure out how to support overloading of commands
      domain = rest_client.domains
      raise RHC::DomainNotFoundException.new("No domains are registered to the user #{config.username}. Please use 'rhc domain create' to create one.") if domain.empty?

      paragraph { say "Updating domain '#{domain[0].id}' to namespace '#{namespace}'" }

      domain[0].update(namespace)

      results do
        say "Success!"
        say "You can use 'rhc domain show' to view any url changes.  Be sure to update any links including the url in your local git config: <local_git_repo>/.git/config"
      end

      0
    end

    summary "Show your configured domains"
    def show
      domains = rest_client.domains
      paragraph do
        say "User Info"
        say "========="
        if domains.length == 0
          say "Namespace: No namespaces found. You can use 'rhc domain create <namespace>' to create a namespace for your applications."
        elsif domains.length == 1
          say "Namespace: #{domains[0].id}"
        else
          domains.each_with_index { |d, i| say "Namespace(#{i}): #{d.id}" }
        end
      end

      paragraph { say "Login: #{config.username}" }
      domains.each do |d|
        paragraph do
          header = "Namespace #{d.id}'s Applications"
          say header
          say "=" * header.length
          apps = d.applications
          if apps.length == 0
            say "No applications found.  You can use 'rhc app create' to create new applications."
          else
            apps.each do |a|
              carts = a.cartridges
              paragraph do
                say a.name
                say "    Framework: #{carts[0].name}"
                say "     Creation: #{a.creation_time}"
                say "         UUID: #{a.uuid}"
                say "      Git URL: #{a.git_url}" if a.git_url
                say "   Public URL: #{a.app_url}" if a.app_url
                say "      Aliases: #{a.aliases.join(', ')}" if a.aliases and not a.aliases.empty?
                say "   Cartridges:"
                if carts.length > 1
                  carts.each do |c|
                    if c.type == 'embedded'
                      connection_url = c.property(:cart_data, :connection_url) || c.property(:cart_data, :job_url)
                      value = connection_url ? " - #{connection_url['value']}" : ""
                      say "       #{c.name}#{value}"
                    end
                  end
                else
                  say "       None"
                end
              end
            end
          end
        end
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
      paragraph { say "Deleting domain '#{namespace}'" }
      domain = rest_client.find_domain namespace

      paragraph do
        begin
          domain.destroy
        rescue Rhc::Rest::ClientErrorException
          # :nocov:
          raise Rhc::Rest::ClientErrorException.new("Domain contains applications. Delete applications first.", 128)
          # :nocov:
        end
      end

      results { say "Success!" }
      0
    end
  end

end
