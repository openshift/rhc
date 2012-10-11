require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/tail'
require 'rhc/config'
describe RHC::Commands::Tail do
  before(:each) do
    RHC::Config.set_defaults
    @rc = MockRestClient.new
    domain = @rc.add_domain("mock-domain-0")
    @app = domain.add_application("mock-app-0", "ruby-1.8.7")
  end

  describe 'help' do
    let(:arguments) { ['tail', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.should exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc tail") }
    end
  end

  describe 'tail' do
    let(:arguments) { ['tail', 'mock-app-0', '--noprompt', '--trace', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
    context 'tail is run on an unreachable domain' do
      it { expect { run }.should raise_error(SocketError) }
    end
    context 'tail succeeds and exits on Interrupt' do
      before (:each) { @app.stub(:tail) { raise Interrupt.new } }
      it { expect { run }.should exit_with_code(0) }
    end
  end
end
