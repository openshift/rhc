require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/cartridge'
require 'rhc/config'

describe RHC::Commands::Cartridge do
  before(:each) do
    RHC::Config.set_defaults
  end

  describe 'run' do
    let(:arguments) { ['cartridge', '--trace', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
      end
      it { expect { run }.should exit_with_code(0) }
      it { run_output.should match("mock_cart-1, mock_cart-2, unique_mock_cart-1") }
    end
  end

  describe 'alias app cartridge' do
    let(:arguments) { ['app', 'cartridge', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
      end
      it { expect { run }.should exit_with_code(0) }
      it { run_output.should match("mock_cart-1, mock_cart-2, unique_mock_cart-1") }
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
      it { expect { run }.should exit_with_code(0) }
      it { run_output.should match("Success") }
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
      it { expect { run }.should exit_with_code(0) }
      it { run_output.should match("Success") }
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
      it { expect { run }.should exit_with_code(154) }
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
      it { expect { run }.should exit_with_code(155) }
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
end
