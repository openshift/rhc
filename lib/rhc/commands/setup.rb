require 'rhc/commands/base'
require 'rhc/wizard'
require 'rhc/config'

module RHC::Commands
  class Setup < Base
    suppress_wizard

    summary "Connects to OpenShift and sets up your keys and domain"
    description <<-DESC
      Connects to an OpenShift server to get you started. Will help you 
      configure your SSH keys, set up a domain, and check for any potential 
      problems with Git or SSH.

      Any options you pass to the setup command will be stored in a
      .openshift/express.conf file in your home directory. If you run 
      setup at a later time, any previous configuration will be reused.

      Pass the --clean option to ignore your saved configuration and only
      use options you pass on the command line. Pass --config FILE to use
      default values from another config (the values will still be written
      to .openshift/express.conf).

      If the server supports authorization tokens, you may pass the 
      --use-token option to instruct the wizard to generate a key for you.
      DESC
    option ["--server NAME"], "Hostname of an OpenShift server", :context => :server_context, :required => true
    option ['--clean'], "Ignore any saved configuration options"
    option ['--use-token'], "Create an authorization token for this server"
    def run
      raise OptionParser::InvalidOption, "Setup can not be run with the --noprompt option" if options.noprompt
      RHC::RerunWizard.new(config, options).run ?  0 : 1
    end
  end
end
