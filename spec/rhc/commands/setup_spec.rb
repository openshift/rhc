require 'spec_helper'
require 'rhc/wizard'
require 'rhc/config'
require 'rhc/commands/setup'
require 'webmock/rspec'

# just test the command runner as we already have extensive wizard tests
describe RHC::Commands::Setup do

  before(:each) do
    RHC::Config.set_defaults
  end

  describe 'run' do
    let(:arguments) { ['setup', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
        @wizard = mock('wizard')
        @wizard.stub!(:run).and_return(true)
        RHC::RerunWizard.stub!(:new) { @wizard }
    end

    context 'when no issues' do
      it "should exit 0" do
        expect { run }.should exit_with_code(0)
      end
    end

    context 'when there is an issue' do
      it "should exit 1" do
        @wizard.stub!(:run).and_return(false)
        expect { run }.should exit_with_code(1)
      end
    end
  end

  describe 'help' do
    let(:arguments) { ['setup', 'help'] }

    context 'help is run' do
      it "should display help" do
        @wizard.stub!(:run).and_return(true)
        expect { run }.should exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Runs the setup wizard") }
    end
  end
end
