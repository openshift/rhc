require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/cartridge'
require 'rhc/config'

describe RHC::Commands::Cartridge do

  def exit_with_code_and_message(code, message = nil)
    expect{ run }.to exit_with_code(code)
    run_output.should match(message) if message
  end

  def succeed_with_message(message = "done")
    exit_with_code_and_message(0,message)
  end

  def fail_with_message(message,code = 1)
    exit_with_code_and_message(code, message)
  end

  def fail_with_code(code = 1)
    exit_with_code_and_message(code)
  end

  before{ user_config }

  describe 'run' do
    let!(:rest_client){ MockRestClient.new }
    context "with all arguments" do
      let(:arguments) { ['cartridge', '--trace', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      it { succeed_with_message /mock_cart-1.*mock_cart-2.*unique_mock_cart-1/m }
    end
    context "without password" do
      let(:arguments) { ['cartridge', '--trace', '--noprompt', '--config', 'test.conf'] }
      it { succeed_with_message /mock_cart-1.*mock_cart-2.*unique_mock_cart-1/m }
    end
  end

  describe 'cartridge list' do
    let(:arguments){ ['cartridge', 'list'] }
    let(:username){ nil }
    let(:password){ nil }
    let(:server){ mock_uri }
    let(:user_auth){ false }

    context 'with valid carts' do
      before{ stub_api; stub_simple_carts }

      it{ run_output.should match /mock_standalone_cart\-1\s+Mock1 Cart\s+web/ }
      it{ run_output.should match /mock_standalone_cart\-2\s+web/ }
      it{ run_output.should match /mock_embedded_cart\-1\s+Mock1 Embedded Cart\s+addon/ }
      it{ run_output.should match /premium_cart\-1 \(\*\)\s+Premium Cart\s+web/ }
      it{ expect{ run }.to exit_with_code(0) }

      context 'with verbose list' do
        let(:arguments){ ['cartridge', 'list', '--verbose', '--trace'] }
        it{ run_output.should match /Mock1 Cart.*\[mock_standalone_cart\-1\] \(web\)/ }
        it{ run_output.should match /mock_standalone_cart\-2 \(web\)/ }
        it{ run_output.should match "Mock2 description\n\n" }
        it{ run_output.should match "Tagged with: scheduled" }
        it{ run_output.should_not match("Tagged with: cartridge") }
        it{ run_output.should match /Premium Cart.*\[premium_cart\-1\*\] \(web\)/ }
      end
    end
  end

  describe 'alias app cartridge' do
    let!(:rest_client){ MockRestClient.new }
    let(:arguments) { ['app', 'cartridge', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      it { succeed_with_message /mock_cart-1.*mock_cart-2.*unique_mock_cart-1/m }
    end
  end

  describe 'cartridge add' do
    let!(:rest_client){ MockRestClient.new }
    let(:arguments) { ['cartridge', 'add', 'mock_cart-1', '--app', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
      end
      it { succeed_with_message /Adding mock_cart-1 to application 'app1' \.\.\. / }
      it { succeed_with_message /Connection URL:\s+http\:\/\/fake\.url/ }
      it { succeed_with_message /Prop1:\s+value1/ }
      it { succeed_with_message /Cartridge added with properties/ }
    end
  end

  describe 'cartridge add' do
    let!(:rest_client){ MockRestClient.new }
    let(:instance) do
      domain = rest_client.add_domain("mock_domain")
      @app = domain.add_application("app1", "mock_type")
      instance = RHC::Commands::Cartridge.new
      RHC::Commands::Cartridge.stub(:new) { instance }
      instance
    end

    context 'with app context' do
      let(:arguments) { ['cartridge', 'add', 'mock_cart-1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      before(:each) do
        instance.stub(:git_config_get) { |key| @app.uuid if key == "rhc.app-uuid" }
      end
      it{ succeed_with_message }
    end

    context 'with named app context' do
      let(:arguments) { ['cartridge', 'add', 'mock_cart-1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      before(:each) do
        instance.stub(:git_config_get) { |key| @app.name if key == "rhc.app-name" }
      end
      it{ succeed_with_message }
    end

    context 'without app context' do
      let(:arguments) { ['cartridge', 'add', 'mock_cart-1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      before(:each) do
        instance.should_receive(:git_config_get).with('rhc.app-name').and_return(nil)
        instance.should_receive(:git_config_get).with('rhc.app-uuid').and_return('')
      end
      it{ fail_with_code }
    end
    context 'without missing app context' do
      let(:arguments) { ['cartridge', 'add', 'mock_cart-1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      before(:each) do
        instance.should_receive(:git_config_get).with('rhc.app-name').and_return(nil)
        instance.should_receive(:git_config_get).with('rhc.app-uuid').and_return('foo')
      end
      it{ fail_with_code }
    end
  end

  describe 'cartridge add' do
    let!(:rest_client){ MockRestClient.new }

    context 'when invoked through an alias' do
      let(:arguments) { ['app', 'cartridge', 'add', 'unique_mock_cart', '--app', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
      end
      it {
        succeed_with_message
      }
    end

    context 'when cartridge does not exist' do
      let(:arguments) { ['cartridge', 'add', 'nomatch_cart', '--app', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
      end
      it{ fail_with_code 154 }
    end

    context 'when multiple carts match' do
      let(:arguments) { ['cartridge', 'add', 'mock_cart', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
      end
      it {
        fail_with_code 155
      }
    end

    context 'when cart is premium' do
      let(:arguments) { ['cartridge', 'add', 'premium_cart', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
      end
      it {
        succeed_with_message /This gear costs an additional \$0\.05 per gear after the first 3 gears\./
      }
    end
  end

  describe 'cartridge remove' do
    let!(:rest_client){ MockRestClient.new }

    context 'when run with --noprompt and without --confirm' do
      let(:arguments) { ['cartridge', 'remove', 'mock_cart-1', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        app.add_cartridge('mock_cart-1')
      end

      it{ fail_with_message "This action requires the --confirm option" }
    end

    context 'when run with confirmation' do
      let(:arguments) { ['cartridge', 'remove', 'mock_cart-1', '--confirm', '--trace', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        @app = domain.add_application("app1", "mock_type")
      end
      it "should remove cartridge" do
        @app.add_cartridge('mock_cart-1')
        expect { run }.to exit_with_code(0)
        # framework cart should be the only one listed
        @app.cartridges.length.should == 1
      end
      it "should raise cartridge not found exception" do
        expect { run }.to raise_error RHC::CartridgeNotFoundException
      end
    end

    context "against a 1.5 server" do
      let!(:rest_client){ nil }
      let(:username){ mock_user }
      let(:password){ 'password' }
      let(:server){ mock_uri }
      let(:arguments){ ['remove-cartridge', 'jenkins-1', '-a', 'foo', '--confirm', '--trace'] }
      before do 
        stub_api(false)
        challenge{ stub_one_domain('test') }
        stub_one_application('test', 'foo').with(:query => {:include => 'cartridges'})
        stub_application_cartridges('test', 'foo', [{:name => 'php-5.3'}, {:name => 'jenkins-1'}])
      end
      before do 
        stub_api_request(:delete, "broker/rest/domains/test/applications/foo/cartridges/jenkins-1").
          to_return({
            :body   => {
              :type => nil,
              :data => nil,
              :messages => [
                {:exit_code => 0, :field => nil, :severity => 'info', :text => 'Removed Jenkins'},
                {:exit_code => 0, :field => nil, :severity => 'result', :text => 'Job URL changed'},
              ]
            }.to_json,
            :status => 200
          })
      end

      it("should not display info returned by the server"){ run_output.should_not match "Removed Jenkins" }
      it("should display prefix returned by the server"){ run_output.should match "Removing jenkins-1" }
      it("should display results returned by the server"){ run_output.should match "Job URL changed" }
      it('should exit successfully'){ expect{ run }.to exit_with_code(0) }
    end
  end

  describe 'cartridge status' do
    let!(:rest_client){ MockRestClient.new }
    let(:arguments) { ['cartridge', 'status', 'mock_cart-1', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
      @domain = rest_client.add_domain("mock_domain")
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
    let!(:rest_client){ MockRestClient.new }
    let(:arguments) { ['cartridge', 'start', 'mock_cart-1', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        app.add_cartridge('mock_cart-1')
      end
      it { run_output.should match(/Starting mock_cart-1 .*done/) }
    end
  end

  describe 'cartridge stop' do
    let!(:rest_client){ MockRestClient.new }
    let(:arguments) { ['cartridge', 'stop', 'mock_cart-1', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        app.add_cartridge('mock_cart-1')
      end
      it { run_output.should match(/Stopping mock_cart-1 .*done/) }
    end
  end

  describe 'cartridge restart' do
    let!(:rest_client){ MockRestClient.new }
    let(:arguments) { ['cartridge', 'restart', 'mock_cart-1', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        app.add_cartridge('mock_cart-1')
      end
      it { run_output.should match(/Restarting mock_cart-1 .*done/) }
    end
  end

  describe 'cartridge reload' do
    let!(:rest_client){ MockRestClient.new }
    let(:arguments) { ['cartridge', 'reload', 'mock_cart-1', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type")
        app.add_cartridge('mock_cart-1')
      end
      it { run_output.should match(/Reloading mock_cart-1 .*done/) }
    end
  end

  describe 'cartridge show' do
    let!(:rest_client){ MockRestClient.new }
    let(:arguments) { ['cartridge', 'show', 'mock_cart-1', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
      domain = rest_client.add_domain("mock_domain")
      app = domain.add_application("app1", "mock_type")
      app.add_cartridge('mock_cart-1')
    end

    context 'when run with exactly the same case as how cartridge was created' do
      it { run_output.should match('Connection URL: http://fake.url') }
      it { run_output.should match(/Prop1:\s+value1/) }
    end
  end

  describe 'cartridge show' do
    let(:arguments) { ['cartridge', 'show', 'Mock_Cart-1', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
      @rc = MockRestClient.new
      domain = @rc.add_domain("mock_domain")
      app = domain.add_application("app1", "mock_type")
      app.add_cartridge('mock_cart-1')
    end

    context 'when run with different case from how cartrige was created' do
      it { run_output.should match('Connection URL: http://fake.url') }
      it { run_output.should match(/Prop1:\s+value1/) }
    end
  end

  describe 'cartridge show' do
    let(:arguments) { ['cartridge', 'show', 'premium_cart', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
      @rc = MockRestClient.new
      domain = @rc.add_domain("mock_domain")
      app = domain.add_application("app1", "mock_type")
      app.cartridges << @rc.cartridges.find {|c| c.name == 'premium_cart'}
    end

    context 'when run with a premium cartridge' do
      it { run_output.should match(/This gear costs an additional \$0\.05 per gear after the first 3 gears./) }
    end
  end

  describe 'cartridge show scaled' do
    let!(:rest_client){ MockRestClient.new }
    let(:arguments) { ['cartridge', 'show', 'mock_type', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        domain = rest_client.add_domain("mock_domain")
        app = domain.add_application("app1", "mock_type", true)
      end
      it { run_output.should match(/Scaling: .*x2 \(minimum/) }
      it { run_output.should match('minimum: 2') }
      it { run_output.should match('maximum: available') }
    end
  end

  describe 'cartridge scale' do
    let!(:rest_client){ MockRestClient.new }
    let(:arguments) { ['cartridge', 'scale', @cart_type || 'mock_type', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] | (@extra_args || []) }

    let(:current_scale) { 1 }
    before do
      domain = rest_client.add_domain("mock_domain")
      @app = domain.add_application("app1", "mock_type", scalable)
      @app.cartridges.first.stub(:current_scale).and_return(current_scale)
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

      it "with an explicit value" do
        @extra_args = ["6"]
        succeed_with_message "minimum: 6, maximum: 6"
      end

      it "with an invalid explicit value" do
        @extra_args = ["a6"]
        fail_with_message "Multiplier must be a positive integer"
      end

      it "with an explicit value and a different minimum" do
        @extra_args = ["6", "--min", "5"]
        succeed_with_message "minimum: 5, maximum: 6"
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

      context "when the operation times out" do
        before{ @app.cartridges.first.should_receive(:set_scales).twice.and_raise(RHC::Rest::TimeoutException.new('Timeout', HTTPClient::ReceiveTimeoutError.new)) }
        it "displays an error" do
          @extra_args = ["--min","2"]
          fail_with_message "The server has closed the connection, but your scaling operation is still in progress"
        end
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

  describe 'cartridge storage' do
    let!(:rest_client){ MockRestClient.new(RHC::Config, 1.3) }
    let(:cmd_base) { ['cartridge', 'storage'] }
    let(:std_args) { ['-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] | (@extra_args || []) }
    let(:cart_type) { ['mock_cart-1'] }

    before(:each) do
      domain = rest_client.add_domain("mock_domain")
      app = domain.add_application("app1", "mock_type", false)
      app.add_cartridge('mock_cart-1', true)
    end

    context 'when run with no arguments' do
      let(:arguments) { cmd_base | std_args }
      it ("should show the mock_type"){ run_output.should match('mock_type') }
      it ('should show mock_cart-1'){ run_output.should match('mock_cart-1') }
    end

    context 'when run for a non-existent cartridge' do
      let(:arguments) { cmd_base | ['bogus_cart'] | std_args }
      it { fail_with_message("There are no cartridges that match 'bogus_cart'.", 154) }
    end

    context 'when run with -c flag' do
      let(:arguments) { cmd_base | ['-c', 'mock_cart-1'] | std_args}
      it "should show storage info for the indicated app and cart" do
        run_output.should match('mock_cart-1')
        run_output.should_not match('mock_type')
      end

      it "should set storage for the indicated app and cart" do
        @extra_args = ["--set", "6GB"]
        run_output.should match('6GB')
      end
    end

    context 'when run with valid arguments' do
      let(:arguments) { cmd_base | cart_type | std_args }
      it "should show storage info for the indicated app and cart" do
        @extra_args = ["--show"]
        run_output.should match('mock_cart-1')
        run_output.should_not match('mock_type')
      end
      it "should add storage for the indicated app and cart" do
        @extra_args = ["--add", "5GB"]
        run_output.should match('10GB')
      end
      it "should remove storage for the indicated app and cart" do
        @extra_args = ["--remove", "5GB"]
        run_output.should match('None')
      end
      it "should warn when told to remove more storage than the indicated app and cart have" do
        @extra_args = ["--remove", "70GB"]
        fail_with_message('The amount of additional storage to be removed exceeds the total amount in use')
      end
      it "should not warn when told to remove more storage than the indicated app and cart have when forced" do
        @extra_args = ["--remove", "70GB", "--force"]
        run_output.should match('None')
      end
      it "should set storage for the indicated app and cart" do
        @extra_args = ["--set", "6GB"]
        run_output.should match('6GB')
      end
      it "should work correctly with a bare number value" do
        @extra_args = ["--set", "6"]
        run_output.should match('6GB')
      end
    end

    context 'when run with invalid arguments' do
      let(:arguments) { cmd_base | cart_type | std_args }
      it "should raise an error when multiple storage operations are provided" do
        @extra_args = ["--show", "--add", "5GB"]
        fail_with_message('Only one storage action can be performed at a time')
      end
      it "should raise an error when the storage amount is not provided" do
        @extra_args = ["--set"]
        fail_with_message('missing argument')
      end
      it "should raise an error when the storage amount is invalid" do
        @extra_args = ["--set", "5ZB"]
        fail_with_message("The amount format must be a number, optionally followed by 'GB'")
      end
    end

    context 'when run against an outdated broker' do
      before { rest_client.stub(:api_version_negotiated).and_return(1.2) }
      let(:arguments) { cmd_base | cart_type | std_args }

      it 'adding storage should raise a version error' do
        @extra_args = ["--add", "1GB"]
        fail_with_message('The server does not support this command \(requires 1.3, found 1.2\).')
      end

    end
  end
end
