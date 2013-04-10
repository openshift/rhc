require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/setup'

# just test the command runner as we already have extensive wizard tests
describe RHC::Commands::Setup do
  subject{ RHC::Commands::Setup }
  let(:instance){ subject.new }
  let!(:config){ base_config }
  before{ described_class.send(:public, *described_class.protected_instance_methods) }
  before{ FakeFS::FileSystem.clear }
  before{ RHC::Config.stub(:home_dir).and_return('/home/mock_user') }

  describe '#run' do
    it{ expects_running('setup').should call(:run).on(instance).with(no_args) }

    let(:arguments) { ['setup', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
      @wizard = mock('wizard')
      @wizard.stub!(:run).and_return(true)
      RHC::RerunWizard.stub!(:new){ @wizard }
    end

    context 'when no issues' do
      it "should exit 0" do
        expect { run }.to exit_with_code(0)
      end
    end

    context 'when there is an issue' do
      it "should exit 1" do
        @wizard.stub!(:run).and_return(false)
        expect { run }.to exit_with_code(1)
      end
    end
  end

  it{ expects_running('setup').should call(:run).on(instance).with(no_args) }
  it{ command_for('setup', '--clean').options.clean.should be_true }

  it{ command_for('setup').options.server.should == 'openshift.redhat.com' }
  it{ command_for('setup', '--server', 'foo.com').options.server.should == 'foo.com' }
  it{ command_for('setup', '--no-create-token').options.create_token.should == false }
  it{ command_for('setup', '--create-token').options.create_token.should == true }

  context "when config has use_authorization_tokens=false" do
    let!(:config){ base_config{ |c, d| d.add('use_authorization_tokens', 'false') } }
    it{ command_for('setup').options.use_authorization_tokens.should == false }
  end
  context "when config has use_authorization_tokens=true" do
    let!(:config){ base_config{ |c, d| d.add('use_authorization_tokens', 'true') } }
    it{ command_for('setup').options.use_authorization_tokens.should == true }
  end

=begin  context 'when libra_server is set' do
    before{ ENV.should_receive(:[]).any_number_of_times.with('LIBRA_SERVER').and_return('bar.com') }
    it{ command_for('setup').config['libra_server'].should == 'bar.com' }
    it{ command_for('setup').options.server.should == 'bar.com' }
    it{ command_for('setup', '--server', 'foo.com').options.server.should == 'foo.com' }
=end  end

  context 'when --clean is used' do
    let!(:config){ base_config{ |config, defaults| defaults.add 'libra_server', 'test.com' } }

    it("should ignore a config value"){ command_for('setup', '--clean').options.server.should == 'openshift.redhat.com' }
  end

  context 'when -d is passed' do
    let(:arguments) { ['setup', '-d', '-l', 'test@test.foo'] }
    # 'y' for the password prompt
    let(:input) { ['', 'y', '', ''] }
    let!(:rest_client){ MockRestClient.new }

    it("succeeds"){ FakeFS{ expect { run input }.to exit_with_code 0 } }
    it("the output includes debug output") do
      FakeFS{ run_output( input ).should match 'DEBUG' }
    end
  end

  context 'when -l is used to specify the user name' do
    let(:arguments) { ['setup', '-l', 'test@test.foo'] }
    # 'y' for the password prompt
    let(:input) { ['', 'y', '', ''] }
    let!(:rest_client){ MockRestClient.new }

    it("succeeds"){ FakeFS{ expect { run input }.to exit_with_code 0 } }
    it("sets the user name to the value given by the command line") do
      FakeFS{ run_output( input ).should match 'test@test.foo' }
    end
  end

  describe 'help' do
    let(:arguments) { ['setup', '--help'] }

    context 'help is run' do
      it "should display help" do
        @wizard.stub!(:run).and_return(true)
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Connects to an OpenShift server to get you started. Will") }
    end
  end

  describe '--autocomplete' do
    let(:arguments) { ['setup', '--autocomplete'] }
    before do 
      path = File.join(Gem.loaded_specs['rhc'].full_gem_path, "autocomplete")
      FakeFS::FileUtils.mkdir_p(path)
      FakeFS::FileUtils.touch(File.join(path, "rhc_bash"))
    end

    context 'is passed' do
      it('should output information') { FakeFS{ run_output.should match("To enable tab-completion") } }
      it('should output the gem path') { FakeFS{ run_output.should match File.join(RHC::Config.home_conf_dir, 'bash_autocomplete') } }
    end
  end
end
