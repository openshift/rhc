require 'rhc/commands/base'
require 'rhc/wizard'
require 'rhc/config'

module RHC::Commands
  class Setup < Base

    summary "Runs the setup wizard to configure your OpenShift account."

    def run
      # TODO: make help subcommand global
      if @args.include? 'help'
        say Commander::Runner.instance.help_formatter.render_command(@command)
        return 0
      end

      w = RHC::RerunWizard.new(config.config_path)
      s = w.run

      # exit 0 on success 1 otherwise
      s ? 0 : 1
    end
  end
end
