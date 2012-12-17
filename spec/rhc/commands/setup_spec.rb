require 'spec_helper'
require 'rhc/wizard'
require 'rhc/config'
require 'rhc/commands/setup'
require 'webmock/rspec'

# just test the command runner as we already have extensive wizard tests
describe RHC::Commands::Setup do

  before(:each) { RHC::Config.set_defaults }

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

  context 'when -d is passed' do
    let(:arguments) { ['setup', '-d', '-l', 'test@test.foo'] }
    # 'y' for the password prompt
    let(:input) { ['', 'y', '', ''] }

    before(:each){ @rc = MockRestClient.new }

    it("succeeds"){ FakeFS{ expect { run input }.should exit_with_code 0 } }
    it("the output includes debug output") do
      FakeFS{ run_output( input ).should match 'DEBUG' }
    end
  end

  context 'when -l is used to specify the user name' do
    let(:arguments) { ['setup', '-l', 'test@test.foo'] }
    # 'y' for the password prompt
    let(:input) { ['', 'y', '', ''] }

    before(:each){ @rc = MockRestClient.new }

    it("succeeds"){ FakeFS{ expect { run input }.should exit_with_code 0 } }
    it("sets the user name to the value given by the command line") do
      FakeFS{ run_output( input ).should match 'test@test.foo' }
    end
  end

  describe 'help' do
    let(:arguments) { ['setup', '--help'] }

    context 'help is run' do
      it "should display help" do
        @wizard.stub!(:run).and_return(true)
        expect { run }.should exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Connects to OpenShift and sets up") }
    end
  end
end
