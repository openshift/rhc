require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/deployment'

describe RHC::Commands::Deployment do

  DEPLOYMENT_APP_NAME = 'mock_app_deploy'

  let!(:rest_client) { MockRestClient.new }

  before do
    user_config
    @rest_app = rest_client.add_domain("mock_domain").add_application(DEPLOYMENT_APP_NAME, 'ruby-1.8.7')
    @rest_app.stub(:ssh_url).and_return("ssh://user@test.domain.com")
    @instance = RHC::Commands::Deployment.new
    RHC::Commands::Deployment.stub(:new).and_return(@instance)
  end

  describe "activate deployment" do
    context "activates 123456" do
      before { Net::SSH.should_receive(:start).exactly(3).times.with('test.domain.com', 'user', :compression => false) }
      let(:arguments) {['deployment', 'activate', '123456', '--app', DEPLOYMENT_APP_NAME]}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Activating deployment '123456' on application #{DEPLOYMENT_APP_NAME} .../)
        run_output.should match(/Success/)
      end
    end

    context "activates 123456 with custom ssh executable" do
      ssh_path = '/usr/bin/ssh'
      before do
        @instance.stub(:exec).and_return([0, "success"])
      end
      let(:arguments) {['deployment', 'activate', '123456', '--app', DEPLOYMENT_APP_NAME, '--ssh', ssh_path]}
      it "should succeed" do
        @instance.should_receive(:run_with_system_ssh).with(/#{ssh_path}/).at_least(:once)
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Activating deployment '123456' on application #{DEPLOYMENT_APP_NAME} .../)
        run_output.should match(/Success/)
      end
    end

    context "fails with ssh error" do
      before (:each) { Net::SSH.should_receive(:start).and_raise(Errno::ECONNREFUSED) }
      let(:arguments) {['deployment', 'activate', '123456', '--app', DEPLOYMENT_APP_NAME]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end
  end

  describe "list deployments" do
    context "simple" do
      let(:arguments) {['deployment', 'list', DEPLOYMENT_APP_NAME]}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Jan 01\, 2000  1\:00 AM\, deployment 0000001/)
        run_output.should match(/Jan 01\, 2000  2\:00 AM\, deployment 0000002/)
        run_output.should match(/Jan 01\, 2000  3\:00 AM\, deployment 0000003 \(rolled back\)/)
        run_output.should match(/Jan 01\, 2000  4\:00 AM\, deployment 0000004 \(rolled back\)/)
        run_output.should match(/Jan 01\, 2000  5\:00 AM\, deployment 0000003 \(rollback to Jan 01\, 2000  3\:00 AM\, rolled back\)/)
        run_output.should match(/Jan 01\, 2000  5\:00 AM\, deployment 0000005 \(rolled back\)/)
        run_output.should match(/Jan 01\, 2000  6\:00 AM\, deployment 0000002 \(rollback to Jan 01\, 2000  2\:00 AM\)/)
      end
    end
  end

  describe "show deployment" do
    context "simple" do
      let(:arguments) {['deployment', 'show', '0000001', '--app', DEPLOYMENT_APP_NAME]}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Deployment ID 0000001/)
      end
    end

    context "fails when deployment is not found" do
      let(:arguments) {['deployment', 'show', 'zee', '--app', DEPLOYMENT_APP_NAME]}
      it "should succeed" do
        expect{ run }.to exit_with_code(131)
        run_output.should match(/Deployment ID 'zee' not found for application #{DEPLOYMENT_APP_NAME}/)
      end
    end
  end

  describe "show configuration" do
    context "simple" do
      let(:arguments) {['app', 'show', '--app', DEPLOYMENT_APP_NAME, '--configuration']}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        #run_output.should match(/Deployment ID 1/)
      end
    end
  end

end
