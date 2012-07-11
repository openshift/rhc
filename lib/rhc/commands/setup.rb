require 'rhc/commands/base'
require 'rhc/wizard'
require 'rhc/config'

module RHC::Commands
  class Setup < Base

    summary "Configure your OpenShift account"
    description "Runs the setup wizard to configure your OpenShift account."
    def run
      # TODO: pass in config object to wizard instead of it using RHC::Config directly
      w = RHC::RerunWizard.new(config.config_path)
      s = w.run

      # exit 0 on success 1 otherwise
      0 if s
      1
    end
  end
end
