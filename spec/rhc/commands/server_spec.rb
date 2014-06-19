require 'spec_helper'
require 'rest_spec_helper'
require 'wizard_spec_helper'
require 'rhc/commands/server'
require 'rhc/config'
require 'rhc/servers'

describe RHC::Commands::Server do
  let(:rest_client) { MockRestClient.new }
  let(:default_options){}
  let(:options){ Commander::Command::Options.new(default_options) }
  let(:config){ RHC::Config.new.tap{ |c| c.stub(:home_dir).and_return('/home/mock_user') } }
  let(:servers){ RHC::Servers.new.tap{|c| c.stub(:home_dir).and_return('/home/mock_user') } }
  before do
    FakeFS.activate!
    FakeFS::FileSystem.clear
  end
  after do
    FakeFS.deactivate!
  end

  describe "server status" do
    before(:each){ user_config }
    describe 'run against a different server' do
      let(:arguments) { ['server', 'status', '--server', 'foo.com', '-l', 'person', '-p', ''] }

      context 'when server refuses connection' do
        before { stub_request(:get, 'https://foo.com/broker/rest/api').with(&user_agent_header).to_raise(SocketError) }
        it('should output an error') { run_output.should =~ /Connected to foo.com.*Unable to connect to the server/m }
        it { expect { run }.to exit_with_code(1) }
      end

      context 'when API is missing' do
        before { stub_request(:get, 'https://foo.com/broker/rest/api').with(&user_agent_header).to_return(:status => 404) }
        it('should output an error') { run_output.should =~ /Connected to foo.com.*server is not responding correctly/m }
        it { expect { run }.to exit_with_code(1) }
      end

      context 'when API is at version 1.2' do
        before do
          rest_client.stub(:api_version_negotiated).and_return('1.2')
        end
        it('should output an error') { run_output.should =~ /Connected to foo.com.*Using API version 1.2/m }
        it { expect { run }.to exit_with_code(0) }
      end
    end

    describe 'run against an invalid server url' do
      let(:arguments) { ['server', 'status', '--server', 'invalid_uri', '-l', 'person', '-p', ''] }
      it('should output an invalid URI error') { run_output.should match('Invalid URI specified: invalid_uri')  }
    end

    describe 'run' do
      let(:arguments) { ['server', 'status'] }
      before{ rest_client.stub(:auth).and_return(nil) }

      context 'when no issues' do
        before { stub_request(:get, 'https://openshift.redhat.com/app/status/status.json').with(&user_agent_header).to_return(:body => {'issues' => []}.to_json) }
        it('should output success') { run_output.should =~ /All systems running fine/ }
        it { expect { run }.to exit_with_code(0) }
      end

      context 'when 1 issue' do
        before do
          stub_request(:get, 'https://openshift.redhat.com/app/status/status.json').with(&user_agent_header).to_return(:body =>
            {'open' => [
              {'issue' => {
                'created_at' => '2011-05-22T17:31:32-04:00',
                'id' => 11,
                'title' => 'Root cause',
                'updates' => [{
                  'created_at' => '2012-05-22T13:48:20-04:00',
                  'description' => 'Working on update'
                }]
              }}]}.to_json)
        end
        it { expect { run }.to exit_with_code(1) }
        it('should output message') { run_output.should =~ /1 open issue/ }
        it('should output title') { run_output.should =~ /Root cause/ }
        it('should contain update') { run_output.should =~ /Working on update/ }
      end
    end
  end

  describe "server list" do
    context "without express.conf or servers.yml" do
      let(:arguments) { ['servers'] }
      it 'should output correctly' do 
        run_output.should =~ /You don't have any servers configured\. Use 'rhc setup' to configure your OpenShift server/
      end
      it { expect { run }.to exit_with_code(0) }
    end

    context "with one entry on servers.yml and no express.conf file" do
      before do
        stub_servers_yml
      end
      let(:arguments) { ['servers'] }
      it 'should output correctly' do 
        run_output.should =~ /Server 'server1'/
        run_output.should =~ /Hostname:\s+openshift1.server.com/
        run_output.should =~ /Login:\s+user1/
        run_output.should =~ /Use Auth Tokens:\s+true/
        run_output.should =~ /Insecure:\s+false/
        run_output.should =~ /You have 1 server configured/
      end
      it { expect { run }.to exit_with_code(0) }
    end

    context "from express.conf and servers.yml" do
      let(:local_config_username){ 'local_config_user' }
      let(:local_config_password){ 'password' }
      let(:local_config_server){ 'openshift.redhat.com' }
      before do
        local_config
        stub_servers_yml
      end
      let(:arguments) { ['servers'] }
      it 'should output correctly' do 
        run_output.should =~ /Server 'online' \(in use\)/
        run_output.should =~ /Hostname:\s+#{local_config_server}/
        run_output.should =~ /Login:\s+#{local_config_username}/
        run_output.should =~ /Server 'server1'/
        run_output.should =~ /Hostname:\s+openshift1.server.com/
        run_output.should =~ /Login:\s+user1/
        run_output.should =~ /Use Auth Tokens:\s+true/
        run_output.should =~ /Insecure:\s+false/
        run_output.should =~ /You have 2 servers configured/
      end
      it { expect { run }.to exit_with_code(0) }
    end

    context "from express.conf and several entries on servers.yml" do
      let(:local_config_username){ 'local_config_user' }
      let(:local_config_password){ 'password' }
      let(:local_config_server){ 'openshift.redhat.com' }
      let(:entries){ 3 }
      before do
        local_config
        stub_servers_yml(entries)
      end
      let(:arguments) { ['servers'] }
      it 'should output correctly' do 
        run_output.should =~ /Server 'online' \(in use\)/
        run_output.should =~ /Hostname:\s+#{local_config_server}/
        Array(1..entries).each do |i|
          run_output.should =~ /Server 'server#{i}'/
          run_output.should =~ /Hostname:\s+openshift#{i}.server.com/
        end
      end
      it { expect { run }.to exit_with_code(0) }
    end
  end

  describe "server show" do
    context "from express.conf" do
      let(:local_config_username){ 'local_config_user' }
      let(:local_config_password){ 'password' }
      let(:local_config_server){ 'openshift.redhat.com' }
      before do 
        local_config
      end
      let(:arguments) { ['server', 'show', 'online'] }
      it 'should output correctly' do 
        run_output.should =~ /Server 'online' \(in use\)/
        run_output.should =~ /Hostname:\s+openshift.redhat.com/
        run_output.should =~ /Login:\s+local_config_user/
      end
      it { expect { run }.to exit_with_code(0) }
    end

    context "from express.conf and servers.yml" do
      let(:arguments) { ['server', 'show', 'openshift1.server.com'] }
      before do
        local_config
        stub_servers_yml do |s|
          s.each do |i|
            i.nickname = nil
            i.use_authorization_tokens = false
            i.insecure = true
          end
        end
      end
      it 'should output correctly' do 
        run_output.should =~ /Server 'openshift1.server.com'/
        run_output.should =~ /Hostname:\s+openshift1.server.com/
        run_output.should =~ /Login:\s+user1/
        run_output.should =~ /Use Auth Tokens:\s+false/
        run_output.should =~ /Insecure:\s+true/
      end
      it { expect { run }.to exit_with_code(0) }
    end

    context "when trying to show server not configured" do
      let(:local_config_server){ 'local.server.com' }
      let(:local_config_username){ 'local_username' }
      before(:each) do
        stub_servers_yml
        local_config
      end
      let(:arguments) { ['server', 'show', 'zee'] }
      it 'should output correctly' do 
        run_output.should =~ /You don't have any server configured with the hostname or nickname 'zee'/
      end
      it { expect { run }.to exit_with_code(166) }
    end
   end

  describe "server add" do
    context "with existing express.conf and successfully adding server" do
      let(:server){ 'openshift1.server.com' }
      let(:username){ 'user1' }
      let(:local_config_server){ 'local.server.com' }
      let(:local_config_username){ 'local_username' }
      let(:token){ 'an_existing_token' }
      let(:arguments) { ['server', 'add', server, '-l', username, '--use-authorization-tokens', '--no-insecure', '--token', token, '--use'] }
      subject{ RHC::ServerWizard.new(config, options, servers) }
      before(:each) do
        RHC::Servers.any_instance.stub(:save!)
        stub_wizard
        local_config
      end
      it 'should output correctly' do 
        run_output.should =~ /Using an existing token for #{username} to login to #{server}/
        run_output.should =~ /Saving configuration to.*express\.conf.*done/
        run_output.should =~ /Saving server configuration to.*servers\.yml.*done/
      end
      it { expect { run }.to exit_with_code(0) }
    end

    context "with existing express.conf trying to add an existing server" do
      let(:local_config_server){ 'local.server.com' }
      let(:local_config_username){ 'local_username' }
      let(:arguments) { ['server', 'add', local_config_server, 'server1', '-l', local_config_username, '--use-authorization-tokens', '--no-insecure'] }
      before(:each) do
        local_config
      end
      it 'should output correctly' do 
        run_output.should =~ /You already have a server configured with the hostname '#{local_config_server}'/
      end
      it { expect { run }.to exit_with_code(165) }
    end

    context "with existing express.conf and servers.yml and adding a new server" do
      let(:server){ 'openshift.server.com' }
      let(:username){ 'user3' }
      let(:server_name){ 'server3' }
      let(:local_config_server){ 'local.server.com' }
      let(:local_config_username){ 'local_username' }
      let(:token){ 'an_existing_token' }
      let(:arguments) { ['server', 'add', server, server_name, '-l', username, '--use-authorization-tokens', '--no-insecure', '--token', token, '--use'] }
      subject{ RHC::ServerWizard.new(config, options, servers) }
      before do
        stub_wizard
        local_config
        stub_servers_yml(2)
      end
      it { run_output.should =~ /Using an existing token for #{username} to login to #{server}/ }
      it { run_output.should =~ /Saving configuration to.*express\.conf.*done/ }
      it { run_output.should =~ /Saving server configuration to.*servers\.yml.*done/ }
      it { expect { run }.to exit_with_code(0) }
    end

    context "with existing express.conf and servers.yml and adding a new server with port and http scheme" do
      let(:server){ 'http://my.server.com:4000' }
      let(:username){ 'user3' }
      let(:server_name){ 'server3' }
      let(:local_config_server){ 'local.server.com' }
      let(:local_config_username){ 'local_username' }
      let(:token){ 'an_existing_token' }
      let(:arguments) { ['server', 'add', server, server_name, '-l', username, '--use-authorization-tokens', '--no-insecure', '--token', token, '--use'] }
      subject{ RHC::ServerWizard.new(config, options, servers) }
      before do
        stub_wizard
        local_config
        stub_servers_yml(2)
      end
      it { run_output.should =~ /Using an existing token for #{username} to login to #{server}/ }
      it { run_output.should =~ /Saving configuration to.*express\.conf.*done/ }
      it { run_output.should =~ /Saving server configuration to.*servers\.yml.*done/ }
      it { expect { run }.to exit_with_code(0) }
    end

    context "with existing express.conf and servers.yml and adding a new mock server" do
      let(:server){ 'openshift.server.com' }
      let(:username){ 'user3' }
      let(:server_name){ 'server3' }
      let(:local_config_server){ 'local.server.com' }
      let(:local_config_username){ 'local_username' }
      let(:arguments) { ['server', 'add', server, server_name, '-l', username, '--skip-wizard'] }
      before do
        local_config
        stub_servers_yml(2)
      end
      it { run_output.should_not =~ /Using an existing token for #{username} to login to #{server}/ }
      it { run_output.should_not =~ /Saving configuration to.*express\.conf.*done/ }
      it { run_output.should =~ /Saving server configuration to.*servers\.yml.*done/ }
      it { expect { run }.to exit_with_code(0) }
    end

    context "with existing express.conf and servers.yml and trying to add an existing server" do
      let(:local_config_username){ 'local_config_user' }
      let(:local_config_password){ 'password' }
      let(:local_config_server){ 'openshift.redhat.com' }
      before do
        local_config
        stub_servers_yml(2)
      end
      let(:arguments) { ['server', 'add', 'foo.com', 'server1', '-l', local_config_username, '--use-authorization-tokens', '--no-insecure'] }
      it 'should output correctly' do 
        run_output.should =~ /You already have a server configured with the nickname 'server1'/
      end
      it { expect { run }.to exit_with_code(164) }
    end

    context "with wizard failure" do
      let(:token){ 'an_existing_token' }
      let(:arguments) { ['server', 'add', 'failure.server.com', 'failed', '-l', 'failer'] }
      before do
        RHC::ServerWizard.any_instance.stub(:run).and_return(false)
        stub_servers_yml
      end
      it { expect { run }.to exit_with_code(1) }
    end
  end

  describe "server remove" do
    context "when trying to remove the server in use" do
      let(:local_config_server){ 'local.server.com' }
      let(:local_config_username){ 'local_username' }
      before(:each) do
        stub_servers_yml
        local_config
      end
      let(:arguments) { ['server', 'remove', local_config_server] }
      it 'should output correctly' do 
        run_output.should =~ /The '#{local_config_server}' server is in use/
      end
      it { expect { run }.to exit_with_code(167) }
    end

    context "when removing successfully" do
      let(:server){ 'openshift5.server.com' }
      let(:local_config_server){ 'local.server.com' }
      let(:local_config_username){ 'local_username' }
      before(:each) do
        stub_servers_yml(5)
        local_config
      end
      let(:arguments) { ['server', 'remove', server] }
      it 'should output correctly' do 
        run_output.should =~ /Removing '#{server}'.*done/
      end
      it { expect { run }.to exit_with_code(0) }
    end

    context "when trying to remove server not configured" do
      let(:local_config_server){ 'local.server.com' }
      let(:local_config_username){ 'local_username' }
      before(:each) do
        stub_servers_yml
        local_config
      end
      let(:arguments) { ['server', 'remove', 'zee'] }
      it 'should output correctly' do 
        run_output.should =~ /You don't have any server configured with the hostname or nickname 'zee'/
      end
      it { expect { run }.to exit_with_code(166) }
    end
  end

  describe "server configure" do
    context "when configuring existing server" do
      let(:server){ 'local.server.com' }
      let(:username){ 'local_username' }

      let(:local_config_server){ server }
      let(:local_config_username){ username }

      let(:local_config_server_new_username){ 'new_username' }
      let(:local_config_server_new_name){ 'new_name' }
      let(:token){ 'an_existing_token' }
      let(:arguments) { ['server', 'configure', local_config_server, '--nickname', local_config_server_new_name, '-l', local_config_server_new_username, '--insecure', '--token', token, '--use'] }
      subject{ RHC::ServerWizard.new(config, options, servers) }
      before do
        stub_wizard
        local_config
        stub_servers_yml
      end
      it { run_output.should =~ /Saving server configuration to.*servers\.yml.*done/ }
      it { run_output.should =~ /Saving configuration to.*express\.conf.*done/ }
      it { run_output.should =~ /Using an existing token for #{local_config_server_new_username} to login to #{server}/ }
      it { run_output.should =~ /Server '#{local_config_server_new_name}' \(in use\)/ }
      it { run_output.should =~ /Hostname:\s+#{server}/ }
      it { run_output.should =~ /Login:\s+#{local_config_server_new_username}/ }
      it { run_output.should =~ /Insecure:\s+true/ }
      it { run_output.should =~ /Now using '#{server}'/ }
      it { expect { run }.to exit_with_code(0) }
    end

    context "with existing express.conf and servers.yml and skipping wizard" do
      let(:server){ 'local.server.com' }
      let(:username){ 'local_username' }

      let(:local_config_server){ server }
      let(:local_config_username){ username }

      let(:local_config_server_new_username){ 'new_username' }
      let(:local_config_server_new_name){ 'new_name' }
      let(:arguments) { ['server', 'configure', local_config_server, '--nickname', local_config_server_new_name, '-l', local_config_server_new_username, '--insecure', 
        '--skip-wizard'] }
      before do
        local_config
        stub_servers_yml
      end
      it { run_output.should =~ /Saving server configuration to.*servers\.yml.*done/ }
      it { run_output.should_not =~ /Saving configuration to.*express\.conf.*done/ }
      it { run_output.should_not =~ /Using an existing token/ }
      it { run_output.should =~ /Server '#{local_config_server_new_name}' \(in use\)/ }
      it { run_output.should_not =~ /Now using '#{server}'/ }
      it { run_output.should =~ /Login:\s+#{local_config_server_new_username}/ }
      it { expect { run }.to exit_with_code(0) }
    end

    context "when trying to remove server not found" do
      let(:local_config_server){ 'local.server.com' }
      let(:local_config_username){ 'local_username' }
      before(:each) do
        stub_servers_yml
        local_config
      end
      let(:arguments) { ['server', 'configure', 'zee', '--insecure'] }
      it 'should output correctly' do 
        run_output.should =~ /You don't have any server configured with the hostname or nickname 'zee'/
      end
      it { expect { run }.to exit_with_code(166) }
    end
  end

  describe "server use" do
    context "when using an existing server" do
      let(:server){ 'local.server.com' }
      let(:username){ 'local_user' }

      let(:local_config_server){ server }
      let(:local_config_username){ username }

      let(:token){ 'an_existing_token' }
      subject{ RHC::ServerWizard.new(config, options, servers) }
      before do
        stub_wizard
        local_config
        stub_servers_yml(3)
      end
      let(:arguments) { ['server', 'use', 'server3', '--token', token] }
      it { run_output.should =~ /Using an existing token for .* to login to openshift3\.server\.com/ }
      it { run_output.should =~ /Saving server configuration to.*servers\.yml.*done/ }
      it { run_output.should =~ /Saving configuration to.*express\.conf.*done/ }
      it { run_output.should =~ /Now using 'openshift3\.server\.com'/ }
      it { expect { run }.to exit_with_code(0) }
    end

    context "with wizard failure" do
      let(:server){ 'local.server.com' }
      let(:username){ 'local_user' }

      let(:local_config_server){ server }
      let(:local_config_username){ username }

      subject{ RHC::ServerWizard.new(config, options, servers) }
      before do
        RHC::ServerWizard.any_instance.stub(:run).and_return(false)
        local_config
        stub_servers_yml
      end 
      let(:arguments) { ['server', 'use', 'local.server.com'] }
      it { expect { run }.to exit_with_code(1) }
    end
  end

  protected 
    def stub_servers_yml(entries=1, &block)
      RHC::Servers.any_instance.stub(:save!)
      RHC::Servers.any_instance.stub(:present?).and_return(true)
      RHC::Servers.any_instance.stub(:load).and_return(
        Array(1..entries).collect do |i|
          RHC::Server.new("openshift#{i}.server.com",
            :nickname => "server#{i}",
            :login => "user#{i}",
            :use_authorization_tokens => true,
            :insecure => false)
        end.tap{|i| yield i if block_given?})
    end

    def stub_wizard
      rest_client.stub(:api)
      rest_client.stub(:user).and_return(double(:login => username))
      rest_client.stub(:supports_sessions?).and_return(true)
      rest_client.stub(:new_session)
      subject.stub(:new_client_for_options).and_return(rest_client)
    end

end
