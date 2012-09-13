require 'rhc/commands/base'
module RHC::Commands
  class Threaddump < Base
    summary "Trigger a thread dump for JBossAS, JBossEAP, and Ruby applications."
    syntax "<application>"
    argument :app, "Name of the application on which to execute the thread dump", []
    def run(app)
      reply = rest_client.threaddump(app)[:message]
      results { say "#{reply}" }
      0
    end
  end
end
