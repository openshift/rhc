require 'rhc/commands/base'
require 'rhc/wizard'
require 'rhc/config'

module RHC::Commands
  class Setup < Base
    suppress_wizard

    summary "Connects to OpenShift and sets up your keys and domain"
    option ["--server hostname"], "Hostname of an OpenShift server", :context => :openshift_server, :required => true
    def run
      raise OptionParser::InvalidOption, "Setup can not be run with the --noprompt option" if options.noprompt
      RHC::RerunWizard.new(config, options).run ?  0 : 1
    end

  end
end
