require 'rhc/commands/base'
require 'rhc/config'
require 'rhc-common'
module RHC::Commands
  class Tail < Base
    summary "Tail the logs of an application"
    syntax "<application>"
    argument :app, "Name of application you wish to view the logs of", ["-a", "--app app"]
    option ["-n", "--namespace namespace"], "Namespace of your application", :context => :namespace_context, :required => true
    option ["-o", "--opts options"], "Options to pass to the server-side (linux based) tail command (applicable to tail command only) (-f is implicit.  See the linux tail man page full list of options.) (Ex: --opts '-n 100')"
    option ["-f", "--files files"], "File glob relative to app (default <application_name>/logs/*) (optional)"
    alias_action :"app tail", :root_command => true, :deprecated => true
    def run(app)
      begin
        rest_domain = rest_client.find_domain(options.namespace)
        rest_app = rest_domain.find_application(app)
        rest_app.tail(options)
      rescue Interrupt
        results { say "Terminating..." }
      end
      0
    end
  end
end
