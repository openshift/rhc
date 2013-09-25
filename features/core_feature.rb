require 'spec_helper'
require 'direct_execution_helper'

describe "rhc core scenarios" do

  it "reports a version" do
    r = rhc '--version'
    r.status.should == 0
    r.stdout.should match /rhc \d+\.\d+\.\d+\b/
  end

  it "displays help" do
    r = rhc 'help'
    r.status.should == 0
    r.stdout.should match "Command line interface for OpenShift"
    r.stdout.should match "Usage: rhc"
    r.stdout.should match "Getting started"
    r.stdout.should match "See 'rhc help options' for a list"
  end

  context "with a clean configuration" do
    before{ use_clean_config }

    it "walks through a configuration" do
      r = rhc :setup, :with => setup_args
      r.stdout.should match 'OpenShift Client Tools'
      r.stdout.should match 'Checking for git ...'
      r.stdout.should match 'Checking for applications ...'
      r.stdout.should match 'Your client tools are now configured.'
      r.status.should == 0

      r = rhc :account
      r.stdout.should match "on #{ENV['RHC_SERVER']}"
      r.stdout.should match 'Gears'
      r.stdout.should match 'Plan'
    end

    it "starts the wizard on default invocation" do
      r = rhc
      r.stdout.should match "OpenShift Client Tools"
    end
  end

  context "when creating an app" do
    when_running 'create-app', 'test1', a_web_cartridge
    before{ no_applications(/^test1/) }
    it "returns the proper info and is in the rest api" do
      status.should == 0
      output.should match "Your application 'test1' is now available"
      output.should match /Gear Size: .*default/
      output.should match /Scaling: .*no/
      output.should match %r(URL: .*http://test1-)
      output.should match "Cloned to"

      apps = client.applications
      apps.should_not be_empty
      apps.should include{ |app| app.name == 'test1' }
    end
  end

  context "with an existing app" do
    before(:all) do
      standard_config
      @app = has_an_application
    end

    let(:app){ @app }

    it "should show app state" do
      r = rhc 'app-show', app.name, '--state'
      r.status.should == 0
      r.stdout.should match "Cartridge #{a_web_cartridge} is started"
    end

    it "should stop and start the app" do
      r = rhc 'stop-app', app.name
      r.status.should == 0
      r.stdout.should match "#{app.name} stopped"
      r = rhc 'start-app', app.name
      r.status.should == 0
      r.stdout.should match "#{app.name} started"
    end

    it "should show gear status" do
      r = rhc 'app-show', app.name, '--gears'
      r.status.should == 0
      r.stdout.lines.to_a.length.should == 3
      r.stdout.should match app.ssh_string
      app.cartridges.map(&:name).each do |c|
        r.stdout.should match c
      end
      r.stdout.should match "started"
    end

    it "should show gear ssh strings" do
      r = rhc 'app-show', app.name, '--gears', 'ssh'
      r.status.should == 0
      r.stdout.lines.to_a.length.should == 1
      r.stdout.chomp.should == app.ssh_string
    end

    context "when the app is cloned" do
      before(:all) do
        rhc('git-clone', @app.name).status.should == 0
        Dir.exists?(@app.name).should be_true
        Dir.chdir @app.name
      end
      let(:git_config){ `git config --list` }

      it "will set Git config values" do
        git_config.should match "rhc.app-id=#{app.id}"
        git_config.should match "rhc.app-name=#{app.name}"
        git_config.should match "rhc.domain-name=#{app.domain_name}"
      end

      it "will infer the current app from the git repository" do
        r = rhc 'show-app'
        r.stdout.should match app.name
        r.stdout.should match app.uuid
        r.stdout.should match app.ssh_string
        r.stdout.should match app.app_url
        (app.cartridges.map(&:name) + app.cartridges.map(&:display_name)).each{ |n| r.stdout.should match n }
        r.status.should == 0
      end

      it "will fetch the quotas from the app" do
        r = rhc 'show-app', '--gears', 'quota'
        r.stdout.chomp.lines.count.should == (app.gear_count + 2)
        app.cartridges.map(&:name).each{ |n| r.stdout.should match n }
        app.cartridges.map(&:gear_storage).each{ |n| r.stdout.should match(RHC::Helpers.human_size(n)) }
        r.status.should == 0
      end

      it "will ssh to the app and run a command" do
        r = rhc 'ssh', '--ssh', ENV['GIT_SSH'], 'echo $OPENSHIFT_APP_NAME'
        r.stdout.should match app.name
        r.status.should == 0
      end
    end
  end
end
