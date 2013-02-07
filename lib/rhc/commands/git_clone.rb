require 'rhc/commands/base'
require 'rhc/git_helpers'

module RHC::Commands
  class GitClone < Base
    summary "Clone and configure an application's repository locally"
    description "This is a convenience wrapper for 'git clone' with the added",
                "benefit of adding configuration data such as the application's",
                "UUID to the local repository.  It also automatically",
                "figures out the git url from the application name so you don't",
                "have to look it up."
    syntax "<app> [--namespace namespace]"
    option ["-n", "--namespace namespace"], "Namespace of the application", :context => :namespace_context, :required => true
    option ["-r", "--repo dir"], "Path to the Git repository (defaults to ./$app_name)"
    argument :app, "The application you wish to clone", ["-a", "--app name"]
    alias_action 'app git-clone', :deprecated => true, :root_command => true
    # TODO: Implement default values for arguments once ffranz has added context arguments
    # argument :directory, "The name of a new directory to clone into", [], :default => nil
    def run(app_name)
      rest_app = rest_client.find_application(options.namespace,app_name)
      git_clone_application(rest_app)

      0
    end

    private
      include RHC::GitHelpers
  end
end
