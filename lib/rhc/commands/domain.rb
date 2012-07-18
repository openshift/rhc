require 'rhc/commands/base'

module RHC::Commands
  class Domain < Base
    summary "Manage your namespace"
    syntax "<action>"
    def run

    end

    argument :namespace, "Namespace for your application(s) (alphanumeric)", "-n", "--namespace namespace"
    option "--timeout timeout", "Timeout, in seconds, for the session"
    summary "Bind a registered user to a domain"
    syntax "<action> <namespace> [--timeout timeout]"
    def create(namespace)
      d = rest_client.domains
      raise Rhc::Rest::BaseException.new("User #{config.username} has already created domain '#{d[0].id}'.  If you wish to change the namespace of this domain please use the command 'rhc domain alter'.", 1) unless d.empty?
      say "Creating domain with namespace '#{namespace}' ... "
      newdomain = rest_client.add_domain(namespace)
      if newdomain.id == namespace
        say "success!"
        say "\n"
        say "You may now create an application using the 'rhc app create' command"
      else
        # we should not get here - the rest libs should have raised any errors
        raise Rhc::Rest::BaseException.new("Unknown Error: this should not have been reached: #{newdomain.inspect}", 255)
      end
      success
    end

    argument :namespace, "Namespace for your application(s) (alphanumeric)", "-n", "--namespace namespace"
    option "--timeout timeout", "Timeout, in secon  ds, for the session"
    summary "Alter namespace (will change urls)."
    syntax "<namespace> [--timeout timeout]"
    def alter(namespace)
      # TODO: Support multiple domains.  Right now we assume one domain so
      #       you don't have to send in the name of the domain you want to change
      #       but in the future this will be manditory if you have more than one
      #       domain.  Figure out how to support overloading of commands
      d = rest_client.domains
      raise Rhc::BaseError("No domains are registered to the user #{config.username}. Be sure to run 'rhc domain create' first.", 1) if d.empty?

      say "Updating domain '#{d[0].id}' to namespace '#{namespace}' ... "
      newdomain = d[0].update(namespace)
      if newdomain.id == namespace
        say "success!"
      else
        # we should not get here - the rest libs should have raised any errors
        raise Rhc::BaseError("Unknown Error: this should not have been reached: #{newdomain.inspect}", 255)
      end
      success
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
          domains.each_with_index { |d, i| puts "Namespace(#{i}): #{d.id}" }
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
                #say "      Git URL: #{a.git_url}"
                #say "   Public URL: #{a.app_url}"
                say "      Aliases: #{a.aliases.join(', ')}" if a.aliases and not a.aliases.empty?
                if carts && !carts.empty?
                  say "   Embedded:"
                  carts.each { |c| say "      #{c.name}" if c.type == 'embedded' }
                else
                  say "      None"
                end
              end
            end
          end
        end
      end
      success
    end

    def status

    end

    def destroy

    end
  end

end
