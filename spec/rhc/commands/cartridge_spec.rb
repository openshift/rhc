require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/cartridge'
require 'rhc/config'

describe RHC::Commands::Cartridge do

  def exit_with_code_and_message(code, message = nil)
    expect{ run }.should exit_with_code(code)
    run_output.should match(message) if message
  end

  def succeed_with_message(message = "Success")
    exit_with_code_and_message(0,message)
  end

  def fail_with_message(message,code = 1)
    exit_with_code_and_message(code, message)
  end

  def fail_with_code(code = 1)
    exit_with_code_and_message(code)
  end


  before(:each) do
    RHC::Config.set_defaults
  end

  describe 'run' do
    let(:arguments) { ['cartridge', '--trace', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
      end
      it { succeed_with_message /mock_cart-1.*mock_cart-2.*unique_mock_cart-1/m }
    end
  end

  describe 'run without password' do
    let(:arguments) { ['cartridge', '--trace', '--noprompt', '--config', 'test.conf'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
      end
      it { succeed_with_message /mock_cart-1.*mock_cart-2.*unique_mock_cart-1/m }
    end
  end

  describe 'alias app cartridge' do
    let(:arguments) { ['app', 'cartridge', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
      end
      it { succeed_with_message /mock_cart-1.*mock_cart-2.*unique_mock_cart-1/m }
    end
  end

  describe 'cartridge add' do
    let(:arguments) { ['cartridge', 'add', 'mock_cart-1', '--app', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
      end
      it {
        succeed_with_message
      }
    end
  end

  describe 'cartridge add with app context' do
    let(:arguments) { ['cartridge', 'add', 'mock_cart-1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        instance = RHC::Commands::Cartridge.new
        instance.stub(:git_config_get) { |key| app.uuid if key == "rhc.app-uuid" }
        RHC::Commands::Cartridge.stub(:new) { instance }
      end
      it {
        succeed_with_message
      }
    end
  end

  describe 'cartridge add with no app context' do
    let(:arguments) { ['cartridge', 'add', 'mock_cart-1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        instance = RHC::Commands::Cartridge.new
        instance.stub(:git_config_get) { |key| "" if key == "rhc.app-uuid" }
        RHC::Commands::Cartridge.stub(:new) { instance }
      end
      it {
        fail_with_code
      }
    end
  end

  describe 'alias app cartridge add' do
    let(:arguments) { ['app', 'cartridge', 'add', 'unique_mock_cart', '--app', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
      end
      it {
        succeed_with_message
      }
    end
  end

  describe 'cartridge add no cart found error' do
    let(:arguments) { ['cartridge', 'add', 'nomatch_cart', '--app', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
      end
      it {
        fail_with_code 154
      }
    end
  end

  describe 'cartridge add too many carts found error' do
    let(:arguments) { ['cartridge', 'add', 'mock_cart', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
      end
      it {
        fail_with_code 155
      }
    end
  end

  describe 'cartridge remove without confirming' do
    let(:arguments) { ['cartridge', 'remove', 'mock_cart-1', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        app.add_cartridge('mock_cart-1')
      end
      it {
        fail_with_message "Removing a cartridge is a destructive operation"
      }
    end
  end

  describe 'cartridge remove' do
    let(:arguments) { ['cartridge', 'remove', 'mock_cart-1', '--confirm', '--trace', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        @app = domain.add_application("app1", "mock_type")
      end
      it "should remove cartridge" do
        @app.add_cartridge('mock_cart-1')
        expect { run }.should exit_with_code(0)
        # framework cart should be the only one listed
        @app.cartridges.length.should == 1
      end
      it "should raise cartridge not found exception" do
        expect { run }.should raise_error RHC::CartridgeNotFoundException
      end
    end
  end

  describe 'cartridge status' do
    let(:arguments) { ['cartridge', 'status', 'mock_cart-1', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
      @rc = MockRestClient.new
      @domain = @rc.add_domain("mock_domain")
      @app = @domain.add_application("app1", "mock_type")
      @app.add_cartridge('mock_cart-1')
    end

    context 'when run' do
      it { run_output.should match('started') }
    end

    context 'when run with cart stopped' do
      before(:each) { @app.find_cartridge('mock_cart-1').stop }
      it { run_output.should match('stopped') }
    end
  end

  describe 'cartridge start' do
    let(:arguments) { ['cartridge', 'start', 'mock_cart-1', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        app.add_cartridge('mock_cart-1')
      end
      it { run_output.should match('start') }
    end
  end

  describe 'cartridge stop' do
    let(:arguments) { ['cartridge', 'stop', 'mock_cart-1', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        app.add_cartridge('mock_cart-1')
      end
      it { run_output.should match('stop') }
    end
  end

  describe 'cartridge restart' do
    let(:arguments) { ['cartridge', 'restart', 'mock_cart-1', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        app.add_cartridge('mock_cart-1')
      end
      it { run_output.should match('restart') }
    end
  end

  describe 'cartridge reload' do
    let(:arguments) { ['cartridge', 'reload', 'mock_cart-1', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        app.add_cartridge('mock_cart-1')
      end
      it { run_output.should match('reload') }
    end
  end

  describe 'cartridge show' do
    let(:arguments) { ['cartridge', 'show', 'mock_cart-1', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
      @rc = MockRestClient.new
      domain = @rc.add_domain("mock_domain")
      app = domain.add_application("app1", "mock_type")
      app.add_cartridge('mock_cart-1')
    end

    context 'when run' do
      it { run_output.should match('Connection URL: http://fake.url') }
    end
  end

  describe 'cartridge show scaled' do
    let(:arguments) { ['cartridge', 'show', 'mock_type', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type", true)
      end
      it { run_output.should match(/Scaling: .*x2 \(minimum/) }
      it { run_output.should match('minimum: 2') }
      it { run_output.should match('maximum: available') }
    end
  end

  describe 'cartridge scale' do
    let(:arguments) { ['cartridge', 'scale', @cart_type || 'mock_type', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] | (@extra_args || []) }

    let(:current_scale) { 1 }
    before(:each) do
      @rc = MockRestClient.new
      domain = @rc.add_domain("mock_domain")
      app = domain.add_application("app1", "mock_type", scalable)
      app.cartridges.first.stub(:current_scale).and_return(current_scale)
    end

    context 'when run with scalable app' do
      let(:scalable){ true }

      it "with no values" do
        fail_with_message "Must provide either a min or max"
      end

      it "with a min value" do
        @extra_args = ["--min","6"]
        succeed_with_message "minimum: 6"
      end

      it "with a max value" do
        @extra_args = ["--max","3"]
        succeed_with_message 'maximum: 3'
      end

      it "with an invalid min value" do
        @extra_args = ["--min","a"]
        fail_with_message "invalid argument: --min"
      end

      it "with an invalid max value" do
        @extra_args = ["--max","a"]
        fail_with_message "invalid argument: --max"
      end
    end

    context 'when run with a nonscalable app' do
      let(:scalable){ false }

      it "with a min value" do
        @extra_args = ["--min","6"]
        fail_with_message "Cartridge is not scalable"
      end
    end
  end
end
