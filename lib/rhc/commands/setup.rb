require 'rhc/commands/base'
require 'rhc/wizard'
require 'rhc/config'

module RHC::Commands
  class Setup < Base
    suppress_wizard

    summary "Easy to use wizard for getting started with OpenShift."
    def run
      raise OptionParser::InvalidOption, "Setup can not be run with the --noprompt option" if options.noprompt
      RHC::RerunWizard.new(config).run ?  0 : 1
    end
  end
end
