require 'rhc/commands/base'

module RHC::Commands
  class EnvVar < Base
    summary "Manage your application environment"
    syntax "<action>"
    description <<-DESC
      Does stuff
      DESC
    alias_action :"app env-var", :root_command => true

    summary "List environment varaibles set on the application"
    syntax "[--namespace NAME] [--app NAME]"
    option ["-n", "--namespace NAME"], "Namespace of the application you are adding the cartridge to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application you are adding the cartridge to", :context => :app_context, :required => true
    def list
      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      env_vars = rest_app.environment_variables

      pager

      say table(env_vars.collect do |e|
        [e.id]
      end)
      0
    end

    summary "Add an environment variable to your application"
    syntax "<name> <value> [--namespace NAME] [--app NAME]"
    option ["-n", "--namespace NAME"], "Namespace of the application you are adding the cartridge to", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application you are adding the cartridge to", :context => :app_context, :required => true
    argument :name,  "The name of the environment variable", ["-n", "--name name"]
    argument :value, "The value of the environment variable", ["-v", "--value value"]    
    def add(name, value)
      say "Adding variable #{name} to application '#{options.app}' ... "

      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      rest_cartridge = rest_app.add_environment_variable(name, value)

      success "Success"
      0
    end

    summary "Remove a environment variable from your application"
    syntax "<name> [--namespace NAME] [--app NAME]"
    argument :name,  "The name of the environment variable", ["-n", "--name name"]
    option ["-n", "--namespace NAME"], "Namespace of the application you are removing the cartridge from", :context => :namespace_context, :required => true
    option ["-a", "--app NAME"], "Application you are removing the cartridge from", :context => :app_context, :required => true
    option ["--confirm"], "Pass to confirm removing the environment variable"
    def remove(name)
      rest_app = rest_client.find_application(options.namespace, options.app, :include => :cartridges)
      confirm_action "Removing a environment variable is a destructive operation that may result in loss of data.\n\nAre you sure you wish to remove environment variable #{name} from '#{rest_app.name}'?"

      say "Removing environment variable #{name} from '#{rest_app.name}' ... "
      rest_app.remove_environment_variable(name)
      success "removed"

      0
    end
  end
end
