require 'rhc/commands/base'
require 'rhc/wizard'
require 'rhc/config'

module RHC::Commands
  class Setup < Base
    suppress_wizard

    summary "Runs the setup wizard to configure your OpenShift account."
    def run
      RHC::RerunWizard.new(config.config_path).run ?  0 : 1
    end
  end
end
