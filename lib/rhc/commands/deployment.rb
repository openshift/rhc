require 'rhc/commands/base'
require 'rhc/deployment_helpers'

module RHC::Commands
  class Deployment < Base
    include RHC::DeploymentHelpers

    summary "Commands for deploying and managing deployments of an application"
    description <<-DESC
      By default OpenShift applications prepare, distribute, and activate deployments
      on every git push. Alternatively, a user may choose to disable automatic
      deployments and use this 'rhc deployment' set of commands to fully control the
      deployment lifecycle. Use these commands to deploy manually from a git reference
      or from a binary file, list and display deployments and also activate existing
      deployments. Check also 'rhc configure-app' to configure your application to
      deploy manually.

      DESC
    syntax "<action>"
    default_action :help

    summary "List the existing deployments of an application"
    description <<-DESC
      List all existing deployments of a given application. Check the 'rhc configure-app'
      command to configure how many deployments are preserved in history.

      DESC
    syntax "<application>"
    takes_application :argument => true
    alias_action :"deployments", :root_command => true
    def list(app)
      rest_app = find_app
      deployment_activations = rest_app.deployment_activations

      raise RHC::DeploymentNotFoundException, "No deployments found for application #{app}." if !deployment_activations.present?

      pager

      display_deployment_list(deployment_activations)
      0
    end

    summary "Show details of the given deployment"
    syntax "<deployment_id> --app NAME [--namespace NAME]"
    description <<-DESC
      Display details of the given deployment id.

      DESC
    takes_application
    argument :id, "The deployment ID to show", ["--id ID"], :optional => false
    def show(id)
      rest_app = find_app
      item = rest_app.deployment_activations.reverse_each.detect{|item| item[:deployment].id == id}

      raise RHC::DeploymentNotFoundException, "Deployment ID '#{id}' not found for application #{rest_app.name}." if !item.present?

      display_deployment(item)
      paragraph { say "Use 'rhc show-app #{rest_app.name} --configuration' to check your deployment configurations." }
      0
    end

    summary "Activate an existing deployment"
    description <<-DESC
      Switch between existing deployments. This command allows you to rollback from one
      deployment to a previous one or activate subsequent deployments. Check the 'rhc
      configure-app' command to configure how many deployments are preserved in history.

      DESC
    syntax "<deployment_id> --app NAME [--namespace NAME]"
    takes_application
    argument :id, "The deployment ID to activate on the application", ["--id ID"], :optional => false
    def activate(id)
      rest_app = find_app

      raise RHC::DeploymentsNotSupportedException.new if !rest_app.supports? "DEPLOY"

      activate_deployment(rest_app, id)
      0
    end

  end
end
