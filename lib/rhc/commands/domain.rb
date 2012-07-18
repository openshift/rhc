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
      puts "you called create with namespace #{namespace}"
    end

    argument :namespace, "Namespace for your application(s) (alphanumeric)", "-n", "--namespace namespace"
    option "--timeout timeout", "Timeout, in secon  ds, for the session"
    summary "Alter namespace (will change urls)."
    syntax "<namespace> [--timeout timeout]"
    def alter(namespace)
      puts "you called alter (#{@args})"
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
