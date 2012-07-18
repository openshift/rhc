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

    def show

    end

    def status

    end

    def destroy

    end
  end

end
