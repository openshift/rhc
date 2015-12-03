require 'rhc/ssh_helpers'

module RHC
  module DeploymentHelpers

    extend self

    include RHC::SSHHelpers

    protected

      def deploy_artifact(rest_app, artifact)
        is_file = File.file?(artifact)
        is_url = URI::ABS_URI.match(artifact).present?

        if rest_app.deployment_type == 'binary'
          if is_file
            deploy_local_file(rest_app, artifact, options.hot_deploy, options.force_clean_build)
          elsif is_url
            deploy_file_from_url(rest_app, artifact, options.hot_deploy, options.force_clean_build)
          else
            paragraph do
              warn "The application '#{rest_app.name}' is configured for binary deployments but the artifact "\
                "provided ('#{artifact}') is not a binary file. Please provide the path to a deployable file on "\
                "your local filesystem or a url, or configure your app to deploy from a git reference with 'rhc "\
                "configure-app #{rest_app.name} --deployment-type git'."
            end
            raise IncompatibleDeploymentTypeException
          end
        elsif is_file || is_url
          paragraph do
            warn "The application '#{rest_app.name}' is configured for git "\
              "reference deployments but the artifact provided ('#{artifact}') is #{is_file ? 'a file' : 'a url'}. Please "\
              "provide a git reference to deploy (branch, tag or commit SHA1) or configure your app to deploy from binaries "\
              "with 'rhc configure-app #{rest_app.name} --deployment-type binary'."
          end
          raise IncompatibleDeploymentTypeException
        else
          deploy_git_ref(rest_app, artifact, options.hot_deploy, options.force_clean_build)
        end
      end

      def deploy_git_ref(rest_app, ref, hot_deploy, force_clean_build)
        say "Deployment of git ref '#{ref}' in progress for application #{rest_app.name} ..."

        ssh_executable = check_ssh_executable! options.ssh

        ssh_url = URI(rest_app.ssh_url)
        remote_cmd = "gear deploy #{ref}#{hot_deploy ? ' --hot-deploy' : ''}#{force_clean_build ? ' --force-clean-build' : ''}"
        ssh_cmd = "#{ssh_executable} -t #{ssh_url.user}@#{ssh_url.host} '#{remote_cmd}'"

        begin
          if options.ssh
            debug "Running #{ssh_cmd}"
            run_with_system_ssh(ssh_cmd)
          else
            ssh_ruby(ssh_url.host, ssh_url.user, remote_cmd)
          end
          success "Success"
        rescue
          warn "Error deploying git ref. You can try to deploy manually with:\n#{ssh_cmd}"
          raise
        end
      end

      def deploy_local_file(rest_app, filename, hot_deploy, force_clean_build)
        filename = File.expand_path(filename)
        say "Deployment of file '#{filename}' in progress for application #{rest_app.name} ..."

        ssh_executable = check_ssh_executable! options.ssh

        ssh_url = URI(rest_app.ssh_url)
        remote_cmd = "oo-binary-deploy#{hot_deploy ? ' --hot-deploy' : ''}#{force_clean_build ? ' --force-clean-build' : ''}"
        if windows?
          ssh_cmd = "type #{filename} | #{ssh_executable} -t #{ssh_url.user}@#{ssh_url.host} '#{remote_cmd}'"
        else
          ssh_cmd = "cat #{filename} | #{ssh_executable} -t #{ssh_url.user}@#{ssh_url.host} '#{remote_cmd}'"
        end

        begin
          if options.ssh
            debug "Running #{ssh_cmd}"
            run_with_system_ssh(ssh_cmd)
          else
            ssh_send_file_ruby(ssh_url.host, ssh_url.user, remote_cmd, filename)
          end
          success "Success"
        rescue
          warn "Error deploying local file. You can try to deploy manually with:\n#{ssh_cmd}"
          raise
        end
      end

      def deploy_file_from_url(rest_app, file_url, hot_deploy, force_clean_build)
        say "Deployment of file '#{file_url}' in progress for application #{rest_app.name} ..."

        ssh_executable = check_ssh_executable! options.ssh

        ssh_url = URI(rest_app.ssh_url)
        file_url = URI(file_url)

        remote_cmd = "oo-binary-deploy#{hot_deploy ? ' --hot-deploy' : ''}#{force_clean_build ? ' --force-clean-build' : ''}"
        ssh_cmd = "#{ssh_executable} -t #{ssh_url.user}@#{ssh_url.host} '#{remote_cmd}'"

        begin
          if options.ssh
            debug "Running #{ssh_cmd}"
            run_with_system_ssh(ssh_cmd)
          else
            ssh_send_url_ruby(ssh_url.host, ssh_url.user, remote_cmd, file_url)
          end
          success "Success"
        rescue
          warn "Error deploying file from url. You can try to deploy manually with:\n#{ssh_cmd}"
          raise
        end
      end

      def activate_deployment(rest_app, deployment_id)
        say "Activating deployment '#{deployment_id}' on application #{rest_app.name} ..."

        ssh_executable = check_ssh_executable! options.ssh

        ssh_url = URI(rest_app.ssh_url)
        remote_cmd = "gear activate --all #{deployment_id}"
        ssh_cmd = "#{ssh_executable} -t #{ssh_url.user}@#{ssh_url.host} '#{remote_cmd}'"

        begin
          if options.ssh
            debug "Running #{ssh_cmd}"
            run_with_system_ssh(ssh_cmd)
          else
            ssh_ruby(ssh_url.host, ssh_url.user, remote_cmd)
          end
          success "Success"
        rescue
          warn "Error activating deployment. You can try to activate manually with:\n#{ssh_cmd}"
          raise
        end
      end

  end
end
