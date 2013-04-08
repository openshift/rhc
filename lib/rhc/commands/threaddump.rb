require 'rhc/commands/base'
module RHC::Commands
  class Threaddump < Base
    summary "Trigger a thread dump for JBoss and Ruby apps"
    syntax "<application>"
    option ["-n", "--namespace namespace"], "Namespace of your application", :context => :namespace_context, :required => true
    argument :app, "Name of the application on which to execute the thread dump", ["-a", "--app name"]
    def run(app)
      rest_app = rest_client.find_application(options.namespace, app)
      rest_app.threaddump.messages.each { |m| say m }

      0
    end
  end
end
