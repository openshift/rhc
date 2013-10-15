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
    @targz_filename = File.dirname(__FILE__) + '/' + DEPLOYMENT_APP_NAME + '.tar.gz'
    FileUtils.cp(File.expand_path('../../assets/targz_sample.tar.gz', __FILE__), @targz_filename)
    File.chmod 0644, @targz_filename unless File.executable? @targz_filename
    @targz_url = 'http://foo.com/path/to/file/' + DEPLOYMENT_APP_NAME + '.tar.gz'
  end

  after do
    File.delete @targz_filename if File.exist? @targz_filename
  end

  describe "configure app" do
    context "manual deployment keeping a history of 10" do
      let(:arguments) {['app', 'configure', '--app', DEPLOYMENT_APP_NAME, '--no-auto-deploy', '--keep-deployments', '10']}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Configuring application '#{DEPLOYMENT_APP_NAME}' .../)
        run_output.should match(/done/)
        @rest_app.auto_deploy.should == false
        @rest_app.keep_deployments.should == 10
      end
    end
  end

  describe "deploy" do
    context "git ref successfully" do
      before { Net::SSH.should_receive(:start).exactly(3).times.with('test.domain.com', 'user', {:compression=>false}) }
      let(:arguments) {['app', 'deploy', 'master', '--app', DEPLOYMENT_APP_NAME]}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Deployment of git ref 'master' in progress for application #{DEPLOYMENT_APP_NAME} .../)
        run_output.should match(/Success/)
      end
    end
    context "binary file successfully" do
      before do
        ssh = double(Net::SSH)
        session = double(Net::SSH::Connection::Session)
        channel = double(Net::SSH::Connection::Channel)
        Net::SSH.should_receive(:start).exactly(3).times.with('test.domain.com', 'user', {:compression=>false}).and_yield(session)
        session.should_receive(:open_channel).exactly(3).times.and_yield(channel)
        channel.should_receive(:exec).exactly(3).times.with("oo-binary-deploy").and_yield(nil, nil)
        channel.should_receive(:on_data).exactly(3).times.and_yield(nil, 'foo')
        channel.should_receive(:on_extended_data).exactly(3).times.and_yield(nil, nil, '')
        channel.should_receive(:on_close).exactly(3).times.and_yield(nil)
        channel.should_receive(:on_process).exactly(3).times.and_yield(nil)
        lines = ''
        File.open(@targz_filename, 'rb') do |file|
          file.chunk(1024) do |chunk|
            lines << chunk
          end
        end
        channel.should_receive(:send_data).exactly(3).times.with(lines)
        channel.should_receive(:eof!).exactly(3).times
        session.should_receive(:loop).exactly(3).times
      end
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', DEPLOYMENT_APP_NAME]}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Deployment of file '#{@targz_filename}' in progress for application #{DEPLOYMENT_APP_NAME} .../)
        run_output.should match(/Success/)
      end
    end
    context "url file successfully" do
      before do
        ssh = double(Net::SSH)
        session = double(Net::SSH::Connection::Session)
        channel = double(Net::SSH::Connection::Channel)
        Net::SSH.should_receive(:start).exactly(3).times.with('test.domain.com', 'user', {:compression=>false}).and_yield(session)
        session.should_receive(:open_channel).exactly(3).times.and_yield(channel)
        channel.should_receive(:exec).exactly(3).times.with("oo-binary-deploy").and_yield(nil, nil)
        channel.should_receive(:on_data).exactly(3).times.and_yield(nil, 'foo')
        channel.should_receive(:on_extended_data).exactly(3).times.and_yield(nil, nil, '')
        channel.should_receive(:on_close).exactly(3).times.and_yield(nil)
        channel.should_receive(:on_process).exactly(3).times.and_yield(nil)
        http = double(Net::HTTP)
        response = double(Net::HTTPResponse)
        Net::HTTP.should_receive(:start).exactly(3).times.with(URI(@targz_url).host).and_yield(http)
        http.should_receive(:request_get).exactly(3).times.with(URI(@targz_url).path).and_yield(response)
        lines = ''
        File.open(@targz_filename, 'rb') do |file|
          file.chunk(1024) do |chunk|
            lines << chunk
          end
        end
        response.should_receive(:read_body).exactly(3).times.and_yield(lines)
        channel.should_receive(:send_data).exactly(3).times.with(lines)
        channel.should_receive(:eof!).exactly(3).times
        session.should_receive(:loop).exactly(3).times
      end
      let(:arguments) {['app', 'deploy', @targz_url, '--app', DEPLOYMENT_APP_NAME]}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Deployment of file '#{@targz_url}' in progress for application #{DEPLOYMENT_APP_NAME} .../)
        run_output.should match(/Success/)
      end
    end
    context "binary file with corrupted file" do
      before do
        ssh = double(Net::SSH)
        session = double(Net::SSH::Connection::Session)
        channel = double(Net::SSH::Connection::Channel)
        Net::SSH.should_receive(:start).exactly(3).times.with('test.domain.com', 'user', {:compression=>false}).and_yield(session)
        session.should_receive(:open_channel).exactly(3).times.and_yield(channel)
        channel.should_receive(:exec).exactly(3).times.with("oo-binary-deploy").and_yield(nil, nil)
        channel.should_receive(:on_data).exactly(3).times.and_yield(nil, 'foo')
        channel.should_receive(:on_extended_data).exactly(3).times.and_yield(nil, nil, 'Invalid file')
        channel.should_receive(:on_close).exactly(3).times.and_yield(nil)
        channel.should_receive(:on_process).exactly(3).times.and_yield(nil)
        lines = ''
        File.open(@targz_filename, 'rb') do |file|
          file.chunk(1024) do |chunk|
            lines << chunk
          end
        end
        channel.should_receive(:send_data).exactly(3).times.with(lines)
        channel.should_receive(:eof!).exactly(3).times
        session.should_receive(:loop).exactly(3).times
      end
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', DEPLOYMENT_APP_NAME]}
      it "should succeed" do
        expect{ run }.to exit_with_code(133)
        run_output.should match(/Deployment of file '#{@targz_filename}' in progress for application #{DEPLOYMENT_APP_NAME} .../)
        run_output.should match(/Invalid file/)
      end
    end
    context "fails when deploying git ref" do
      before (:each) { Net::SSH.should_receive(:start).and_raise(Errno::ECONNREFUSED) }
      let(:arguments) {['app', 'deploy', 'master', '--app', DEPLOYMENT_APP_NAME]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end
    context "fails when deploying binary file" do
      before (:each) { Net::SSH.should_receive(:start).and_raise(Errno::ECONNREFUSED) }
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', DEPLOYMENT_APP_NAME]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end
    context "fails when deploying binary file" do
      before (:each) { Net::SSH.should_receive(:start).and_raise(SocketError) }
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', DEPLOYMENT_APP_NAME]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end
    context "fails when deploying url file" do
      before (:each) { Net::SSH.should_receive(:start).and_raise(Errno::ECONNREFUSED) }
      let(:arguments) {['app', 'deploy', @targz_url, '--app', DEPLOYMENT_APP_NAME]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end
    context "fails when deploying url file" do
      before (:each) { Net::SSH.should_receive(:start).and_raise(SocketError) }
      let(:arguments) {['app', 'deploy', @targz_url, '--app', DEPLOYMENT_APP_NAME]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end
  end

  describe "activate deployment" do
    context "activates 123456" do
      before { Net::SSH.should_receive(:start).exactly(3).times.with('test.domain.com', 'user', {}) }
      let(:arguments) {['deployment', 'activate', '123456', '--app', DEPLOYMENT_APP_NAME]}
      it "should succeed" do
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
        run_output.should match(/Deployment ID 1/)
        run_output.should match(/Deployment ID 2/)
      end
    end
  end

  describe "show deployment" do
    context "simple" do
      let(:arguments) {['deployment', 'show', '1', '--app', DEPLOYMENT_APP_NAME]}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Deployment ID 1/)
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