require 'rhc/commands/base'
module RHC::Commands
  class Threaddump < Base
    summary "Trigger a thread dump for JBossAS, JBossEAP, and Ruby applications."
    syntax "<application>"
    option ["-n", "--namespace namespace"], "Namespace to add your application to", :context => :namespace_context, :required => true
    argument :app, "Name of the application on which to execute the thread dump", ["-a", "--app name"]
    def run(app)
      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(app)
      reply = rest_app.threaddump[:message]
      say "#{reply}"
      0
    end
  end
end
