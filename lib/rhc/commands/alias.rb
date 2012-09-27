require 'rhc/commands/base'
require 'rhc/config'
require 'rhc-common'
module RHC::Commands
  class Alias < Base
    summary "Add or remove a custom domain name for the application"
    syntax "<command> <application> <alias> [--namespace namespace]"
    default_action :help

    summary "Add a custom domain name for the application"
    syntax "<application> <alias> [--namespace namespace]"
    argument :app, "Application name (required)", []
    argument :app_alias, "Custom domain name for the application", []
    option ["-n", "--namespace namespace"], "Namespace of your application", :context => :namespace_context, :required => true
    alias_action :"app add-alias", :root_command => true, :deprecated => true
    def add(app, app_alias)
      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(app)
      response = rest_app.add_alias(app_alias)
      results { say response.messages.first } if response.messages
      0
    end

    summary "Remove a custom domain name for the application"
    syntax "<application> <alias> [--namespace namespace]"
    argument :app, "Application name (required)", []
    argument :app_alias, "Custom domain name for the application", []
    option ["-n", "--namespace namespace"], "Namespace of your application", :context => :namespace_context, :required => true
    alias_action :"app remove-alias", :root_command => true, :deprecated => true
    def remove(app, app_alias)
      rest_domain = rest_client.find_domain(options.namespace)
      rest_app = rest_domain.find_application(app)
      response = rest_app.remove_alias(app_alias)
      results { say response.messages.first } if response.messages
      0
    end
  end
end
