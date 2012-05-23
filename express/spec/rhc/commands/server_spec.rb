require 'spec_helper'
require 'rhc/commands/server'

describe RHC::Commands::Server do
  describe 'run' do
    let(:arguments) { ['server'] }

    context 'when no issues' do
      before { stub_request(:get, 'https://openshift.redhat.com/app/status/status.json').to_return(:body => {'issues' => []}.to_json) }
      it { expect { run }.should exit_with_code(0) }
      it('should output success') { run_output.should =~ /All systems running fine/ }
    end

    context 'when 1 issue' do
      before do 
        stub_request(:get, 'https://openshift.redhat.com/app/status/status.json').to_return(:body => 
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
