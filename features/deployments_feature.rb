require 'spec_helper'
require 'direct_execution_helper'
require 'httpclient'
require 'fileutils'

describe "rhc deployment scenarios" do
  context "with an existing app" do
    before(:all) do
      standard_config
      @app = has_an_application
    end

    let(:app){ @app }

    it "should display deployment list" do
      r = list_deployments
      r.stdout.should match /Deployment ID .*\(active\)/
      r.stdout.should match /Git Reference:\s+master/
      r.stdout.should match /Hot Deploy:\s+false/
      r.stdout.should match /Force Clean Build:\s+false/
    end

    it "should configure the app for a git ref deployment" do
      r = configure_app_for_manual_git_deployment
      r.stdout.should match /Deployment:\s+manual/
      r.stdout.should match /Keep Deployments:\s+10/
      r.stdout.should match /Deployment Type:\s+git/
      r.stdout.should match /Deployment Branch:\s+master/
    end

    it "should configure the app for a binary deployment" do
      r = configure_app_for_manual_binary_deployment
      r.stdout.should match /Deployment:\s+manual/
      r.stdout.should match /Keep Deployments:\s+10/
      r.stdout.should match /Deployment Type:\s+binary/
      r.stdout.should match /Deployment Branch:\s+master/
    end

    it "should deploy a git ref" do
      configure_app_for_manual_git_deployment
      r = deploy_master
      r.stdout.should match /Deployment of git ref 'master' in progress for application #{app.name}/
      r.stdout.should match /Success/
      r = list_deployments
      r.stdout.should match /Deployment ID .*\(active\)/
      r.stdout.should match /Deployment ID .*\(inactive\)/
    end

    it "should perform a complete deploy workflow" do
      configure_app_for_manual_git_deployment
      edit_simple_change 'Welcome to Test'
      app_page_content.should match /Welcome to OpenShift/
      app_page_content.should_not match /Welcome to Test/
      deploy_master
      app_page_content.should match /Welcome to Test/
      app_page_content.should_not match /Welcome to OpenShift/
      deployment_id = find_inactive_deployment
      deployment_id.should_not be_nil
      activate deployment_id
      app_page_content.should match /Welcome to OpenShift/
      app_page_content.should_not match /Welcome to Test/
    end

    private
      def configure_app_for_manual_git_deployment
        ensure_command 'configure-app', app.name, '--no-auto-deploy', '--keep-deployments', 10, '--deployment-type', 'git'
      end

      def configure_app_for_manual_binary_deployment
        ensure_command 'configure-app', app.name, '--no-auto-deploy', '--keep-deployments', 10, '--deployment-type', 'binary'
      end

      def list_deployments
        ensure_command 'deployments', app.name
      end

      def deploy(ref)
        ensure_command 'deploy', ref, '-a', app.name
      end

      def deploy_master
        deploy 'master'
      end

      def activate(deployment_id)
        ensure_command 'activate-deployment', deployment_id, '-a', app.name
      end

      def snapshot_deployment
        ensure_command 'save-snapshot', app.name, '--deployment'
      end

      def git_clone
        ensure_command 'git-clone', app.name, '-r', git_directory
        Dir.exists?(git_directory).should be_true
      end

      def edit_simple_change(content)
        FileUtils.rm_rf git_directory
        git_clone
        Dir.chdir git_directory
        `sed -i "s/Welcome to OpenShift/#{content}/" php/index.php`
        `git commit -a -m "Commit from Feature Tests"`
        `git push origin master`
        Dir.chdir '../'
        FileUtils.rm_rf git_directory
      end

      def app_page_content
        HTTPClient.new.get_content(app.app_url)
      end

      def git_directory
        "#{app.name}_feature_tests_repo"
      end

      def find_inactive_deployment
        r = list_deployments
        r.stdout.match(/Deployment ID (\w*) \(inactive\)/)[1]
      end

      def ensure_command(*args)
        r = rhc *args
        r.status.should == 0
        r
      end
  end
end
