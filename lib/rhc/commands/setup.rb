require 'rhc/commands/base'
require 'rhc/wizard'
require 'rhc/config'

module RHC::Commands
  class Setup < Base

    summary "Runs the setup wizard to configure your OpenShift account."
    suppress_wizard
    def run
      w = RHC::RerunWizard.new(config.config_path)
      # exit 0 on success 1 otherwise
      w.run ? command_success : 1
    end
  end
end
