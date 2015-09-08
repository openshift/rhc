require 'spec_helper'
require 'direct_execution_helper'

describe "rhc app scenarios" do
  context "with an existing app" do
    before(:all) do
      standard_config
      @app = has_an_application
    end

    let(:app){ @app }

    it "should clone successfully" do
      # The following works around an issue with strict host key checking.
      # create-app --from-app uses SSH to copy the application.  However,
      # this test uses a new application, so without this workaround, create-app
      # --from-app will be trying to log into the application for the first
      # time, and so SSH will not recognize the host key and will prompt for
      # confirmation, causing the test to hang and eventually time out.  To work
      # around the problem, we tell rhc to initiate an SSH connection using
      # GIT_SSH (which disables strict host key checking), which will cause SSH
      # to add the host to ~/.ssh/known_hosts, which will allow the subsequent
      # create-app --from-app command to succeed.
      rhc 'ssh', '--ssh', ENV['GIT_SSH'], app.name, '--', 'true'

      app_name = "clone#{random}"
      r = rhc 'create-app', app_name, '--from-app', app.name
      r.stdout.should match /Domain:\s+#{app.domain}/
      r.stdout.should match /Cartridges:\s+#{app.cartridges.collect{|c| c.name}.join(', ')}/
      r.stdout.should match /From app:\s+#{app.name}/
      r.stdout.should match /Gear Size:\s+Copied from '#{app.name}'/
      r.stdout.should match /Scaling:\s+#{app.scalable? ? 'yes' : 'no'}/
      r.stdout.should match /Setting deployment configuration/
      r.stdout.should match /Pulling down a snapshot of application '#{app.name}'/
    end
  end
end
