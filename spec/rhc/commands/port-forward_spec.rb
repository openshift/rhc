require 'spec_helper'
require 'rhc/commands/port-forward'
require 'rhc/config'

describe RHC::Commands::PortForward do
  before(:each) do
    RHC::Config.set_defaults
  end

  describe 'run' do
    let(:arguments) { ['port-forward', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p', 'password', '--app', 'mockapp'] }

    context 'when a scaling app' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        domain.add_application 'mockapp', 'mock-1.0', true
      end
      it "should error out" do
        expect { run }.should exit_with_code(101)
        @rc.domains[0].id.should == 'mockdomain'
        @rc.domains[0].applications.size.should == 1
        @rc.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should match("This utility does not currently support scaled applications. You will need to set up port forwarding manually.") }
    end

  end
end
