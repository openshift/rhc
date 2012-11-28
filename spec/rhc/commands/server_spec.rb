require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/server'
require 'rhc/config'

describe RHC::Commands::Server do
  before(:each){ user_config }

  describe 'run against a different server' do
    let(:arguments) { ['server', '--server', 'foo.com', '-l', 'person', '-p', ''] }

    context 'when server refuses connection' do
      before { stub_request(:get, 'https://person:@foo.com/broker/rest/api').with(&user_agent_header).to_raise(SocketError) }
      it('should output an error') { run_output.should =~ /Connected to foo.com.*Unable to connect to the server/m }
      it { expect { run }.should exit_with_code(1) }
    end

    context 'when API is missing' do
      before { stub_request(:get, 'https://person:@foo.com/broker/rest/api').with(&user_agent_header).to_return(:status => 404) }
      it('should output an error') { run_output.should =~ /Connected to foo.com.*server is not responding correctly/m }
      it { expect { run }.should exit_with_code(1) }
    end

    context 'when API is at version 1.2' do
      before do 
        rc = MockRestClient.new
        rc.stub(:api_version_negotiated).and_return('1.2')
      end
      it('should output an error') { run_output.should =~ /Connected to foo.com.*Using API version 1.2/m }
      it { expect { run }.should exit_with_code(0) }
    end
  end

  describe 'run' do
    let(:arguments) { ['server'] }

    context 'when no issues' do
      before { stub_request(:get, 'https://openshift.redhat.com/app/status/status.json').with(&user_agent_header).to_return(:body => {'issues' => []}.to_json) }
      it('should output success') { run_output.should =~ /All systems running fine/ }
      it { expect { run }.should exit_with_code(0) }
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
      it { expect { run }.should exit_with_code(1) }
      it('should output message') { run_output.should =~ /1 open issue/ }
      it('should output title') { run_output.should =~ /Root cause/ }
      it('should contain update') { run_output.should =~ /Working on update/ }
    end
  end
end
