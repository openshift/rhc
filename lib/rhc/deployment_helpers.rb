require 'rhc/ssh_helpers'
require 'net/http'

module RHC
  module DeploymentHelpers

    extend self

    include RHC::SSHHelpers

    protected

      def deploy_artifact(rest_app, artifact, hot_deploy, force_clean_build)
        File.file?(artifact) ?
          deploy_local_file(rest_app, artifact, hot_deploy, force_clean_build) :
        artifact =~ /^#{URI::regexp}$/ ?
          deploy_file_from_url(rest_app, artifact, hot_deploy, force_clean_build) :
        deploy_git_ref(rest_app, artifact, hot_deploy, force_clean_build)
      end

      def deploy_git_ref(rest_app, ref, hot_deploy, force_clean_build)
        say "Deployment of git ref '#{ref}' in progress for application #{rest_app.name} ..."

        ssh_url = URI(rest_app.ssh_url)
        remote_cmd = "gear deploy #{ref}#{hot_deploy ? ' --hot-deploy' : ''}#{force_clean_build ? ' --force-clean-build' : ''}"

        begin
          ssh_ruby(ssh_url.host, ssh_url.user, remote_cmd)
          success "Success"
        rescue
          warn "Error trying to deploy git ref. You can ssh to your application and try to deploy manually with:\n#{remote_cmd}"
          raise
        end
      end

      def deploy_local_file(rest_app, filename, hot_deploy, force_clean_build)
        filename = File.expand_path(filename)
        say "Deployment of file '#{filename}' in progress for application #{rest_app.name} ..."

        ssh_url = URI(rest_app.ssh_url)
        remote_cmd = "oo-binary-deploy#{hot_deploy ? ' --hot-deploy' : ''}#{force_clean_build ? ' --force-clean-build' : ''}"

        begin
          ssh_send_file_ruby(ssh_url.host, ssh_url.user, remote_cmd, filename)
          success "Success"
        rescue
          warn "Error trying to deploy local file. You can ssh to your application and try to deploy manually with:\n#{remote_cmd}"
          raise
        end
      end

      def deploy_file_from_url(rest_app, file_url, hot_deploy, force_clean_build)
        say "Deployment of file '#{file_url}' in progress for application #{rest_app.name} ..."

        ssh_url = URI(rest_app.ssh_url)
        file_url = URI(file_url)

        remote_cmd = "oo-binary-deploy#{hot_deploy ? ' --hot-deploy' : ''}#{force_clean_build ? ' --force-clean-build' : ''}"

        begin
          ssh_send_url_ruby(ssh_url.host, ssh_url.user, remote_cmd, file_url)
          success "Success"
        rescue
          warn "Error trying to deploy file from url. You can ssh to your application and try to deploy manually with:\n#{remote_cmd}"
          raise
        end
      end

      def activate_deployment(rest_app, deployment_id)
        say "Activating deployment '#{deployment_id}' on application #{rest_app.name} ..."

        ssh_url = URI(rest_app.ssh_url)
        remote_cmd = "gear activate #{deployment_id}"

        begin
          ssh_ruby(ssh_url.host, ssh_url.user, remote_cmd)
          success "Success"
        rescue
          warn "Error trying to activate deployment. You can ssh to your application and try to activate manually with:\n#{remote_cmd}"
          raise
        end
      end

  end
end
