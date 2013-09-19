require 'rhc/commands/base'
require 'rhc/git_helpers'

module RHC::Commands
  class GitClone < Base
    summary "Clone and configure an application's repository locally"
    description "This is a convenience wrapper for 'git clone' with the added",
                "benefit of adding configuration data such as the application's",
                "UUID to the local repository.  It also automatically",
                "figures out the Git url from the application name so you don't",
                "have to look it up."
    syntax "<app> [--namespace NAME]"
    takes_application :argument => true
    option ["-r", "--repo dir"], "Path to the Git repository (defaults to ./$app_name)"
    alias_action 'app git-clone', :deprecated => true, :root_command => true
    # TODO: Implement default values for arguments once ffranz has added context arguments
    # argument :directory, "The name of a new directory to clone into", [], :default => nil
    def run(app_name)
      rest_app = find_app
      dir = git_clone_application(rest_app)
      success "Your application Git repository has been cloned to '#{system_path(dir)}'"

      0
    end

    private
      include RHC::GitHelpers
  end
end
