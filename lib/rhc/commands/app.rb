require 'rhc/commands/base'

module RHC::Commands
  class App < Base
    summary "Commands for creating and managing applications"
    description "Creates and controls an OpenShift application.  To see the list of all applications use the rhc domain show command.  Note that delete is not reversible and will stop your application and then remove the application and repo from the remote server. No local changes are made."
    syntax "<action>"
    default_action :help

    summary "Create an application and adds it to a domain"
    syntax "<name> <cartridge> [... <other cartridges>][--namespace namespace]"
    option ["-n", "--namespace namespace"], "Namespace to add your application to", :context => :namespace_context, :required => true
    option ["-g", "--gear-size size"], "The  size  of the gear for this app. Available gear sizes depend on the type of account you have."
    option ["-r", "--repo"], "Git Repo path (defaults to ./$app_name) (applicable to the  create command)"
    option ["--no-git", "--nogit"], "Only  create  remote space, don't pull it locally"
    option ["--no-dns", "--nodns"], "Skip DNS check. Must be used in combination with --nogit"
    option ["--enable-jenkins"], "Indicates to create a Jenkins application (if not already available)  and  embed the Jenkins client into this application. The default name will be 'jenkins' if not specified. Note that --nodns is ignored for the creation of the Jenkins application."
    argument :name, "The name you wish to give your application", ["-a", "--app name"]
    argument :cartridge, "The first cartridge added to the application. Usually a web framework", ["-t", "--type cartridge"]
    argument :additional_cartridges, "A list of other cartridges such as databases you wish to add. Cartridges can also be added later using 'rhc cartridge add'", [], :arg_type => :list
    def create(name, cartridge, additional_cartridges)
      repo = options.repo || name

      say "Creating '#{name}' application in domain '#{option.namespace}'"
      rest_domain = rest_client.find_domain(option.namespace)

      app_options = {:cartridge => cartridge}
      app_options[:gear_profile] = options.gear_size if options.gear_size
      app_options[:scaling] = options.scaling if options.scaling

      rest_domain.add_application(name, app_options)

      results { say "Success!" }

      0
    end
  end
end
