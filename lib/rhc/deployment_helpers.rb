require 'rhc/ssh_helpers'

module RHC
  module DeploymentHelpers

    extend self

    include RHC::SSHHelpers

    protected

      def deploy_git_ref(rest_app, ref, hot_deploy, force_clean_build)
        say "Deployment of git ref '#{ref}' in progress for application #{rest_app.name} ..."

        ssh_url = URI(rest_app.ssh_url)
        remote_cmd = "gear deploy #{ref}#{hot_deploy ? ' --hot-deploy' : ''}#{force_clean_build ? ' --force-clean-build' : ''}"

        begin
          ssh_ruby(ssh_url.host, ssh_url.user, remote_cmd)
          success "Success"
        rescue
          warn "You can ssh to your application and try to deploy manually with:\n#{remote_cmd}"
          raise
        end
      end

      def deploy_file(rest_app, filename, hot_deploy, force_clean_build)
        filename = File.expand_path(filename)
        say "Deployment of file '#{filename}' in progress for application #{rest_app.name} ..."

        ssh_url = URI(rest_app.ssh_url)
        remote_cmd = "oo-binary-deploy#{hot_deploy ? ' --hot-deploy' : ''}#{force_clean_build ? ' --force-clean-build' : ''}"

        begin
          ssh_send_file_ruby(ssh_url.host, ssh_url.user, remote_cmd, filename)
          success "Success"
        rescue
          warn "You can ssh to your application and try to deploy manually with:\n#{remote_cmd}"
          raise
        end
      end

      def activate_deployment(rest_app, deployment_id)
        say "Activating deployment '#{deployment_id}' on application #{rest_app.name} ... "

        ssh_url = URI(rest_app.ssh_url)
        remote_cmd = "gear activate #{deployment_id}"

        begin
          ssh_ruby(ssh_url.host, ssh_url.user, remote_cmd)
          success "done"
        rescue
          warn "You can ssh to your application and try to activate manually with:\n#{remote_cmd}"
          raise
        end
      end

  end
end
