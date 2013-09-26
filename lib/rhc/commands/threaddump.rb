require 'rhc/commands/base'
module RHC::Commands
  class Threaddump < Base
    summary "Trigger a thread dump for JBoss and Ruby apps"
    syntax "<application>"
    takes_application :argument => true
    def run(app)
      rest_app = find_app
      rest_app.threaddump.messages.each { |m| say m }

      0
    end
  end
end
