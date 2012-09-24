require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/app'
require 'rhc/config'

describe RHC::Commands::App do
  before(:each) do
    FakeFS.activate!
    RHC::Config.set_defaults
    instance = RHC::Commands::App.new
    RHC::Commands::App.stub(:new) do
      instance.stub(:git_config_get) { "" }
      instance.stub(:git_config_set) { "" }
      Kernel.stub(:sleep) { }
      instance.stub(:git_clone_repo) do |git_url, repo_dir|
        raise RHC::GitException, "Error in git clone" if repo_dir == "giterrorapp"
        Dir::mkdir(repo_dir)
      end
      instance.stub(:host_exist?) do |host|
        return false if host.match("dnserror")
        true
      end
      instance
    end
  end

  after(:each) do
    FakeFS::FileSystem.clear
    FakeFS.deactivate!
  end

  describe 'app create' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_standalone_cart-1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
      end
      it { expect { run }.should exit_with_code(0) }
      it { run_output.should match("Success") }
    end
  end

  describe 'app create no cart found error' do
    let(:arguments) { ['app', 'create', 'app1', 'nomatch_cart', '--trace', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
      end
      it { expect { run }.should raise_error(RHC::CartridgeNotFoundException) }
    end
  end

  describe 'app create too many carts found error' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_standalone_cart', '--trace', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
      end
      it { expect { run }.should raise_error(RHC::MultipleCartridgesException) }
    end
  end

  describe 'app create enable-jenkins' do
    let(:arguments) { ['app', 'create', 'app1', '--trace', 'mock_unique_standalone_cart', '--enable-jenkins', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        @domain = @rc.add_domain("mockdomain")
      end
      it "should create a jenkins app and a regular app with an embedded jenkins client" do
        expect { run }.should exit_with_code(0)
        jenkins_app = @domain.find_application("jenkins")
        jenkins_app.cartridges[0].name.should == "jenkins-1.4"
        app = @domain.find_application("app1")
        app.find_cartridge("jenkins-client-1.4")
      end
    end
  end

  describe 'app create enable-jenkins with --no-dns' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--trace', '--enable-jenkins', '--no-dns', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
      end
      it { expect { run }.should raise_error(ArgumentError, /The --no-dns option can't be used in conjunction with --enable-jenkins/) }
    end
  end

  describe 'app create enable-jenkins with same name as app' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--trace', '--enable-jenkins', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
      end
      it { expect { run }.should raise_error(ArgumentError, /You have named both your main application and your Jenkins application/) }
    end
  end

  describe 'app create enable-jenkins with existing jenkins' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--trace', '--enable-jenkins', 'jenkins2', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        @domain = @rc.add_domain("mockdomain")
        @domain.add_application("jenkins", "jenkins-1.4")
      end
      it "should use existing jenkins" do
        expect { run }.should exit_with_code(0)
        expect { @domain.find_application("jenkins") }.should_not raise_error
        expect { @domain.find_application("jenkins2") }.should raise_error(RHC::ApplicationNotFoundException)
      end
    end
  end

  describe 'app create enable-jenkins named after existing app' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--trace', '--enable-jenkins', 'app2', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        domain.add_application("app2", "mock_unique_standalone_cart")
      end
      it { expect { run }.should raise_error(ArgumentError, /You have named your Jenkins application the same as an existing application/) }
    end
  end

  describe 'app delete' do
    let(:arguments) { ['app', 'delete', '--trace', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        @domain = @rc.add_domain("mockdomain")
      end
      it "should not remove app when no is sent as input" do
        @app = @domain.add_application("app1", "mock_type")
        expect { run(["no"]) }.should exit_with_code(0)
        @domain.applications.length.should == 1
        @domain.applications[0] == @app
      end

      it "should remove app when yes is sent as input" do
        @app = @domain.add_application("app1", "mock_type")
        expect { run(["yes"]) }.should exit_with_code(0)
        @domain.applications.length.should == 0
      end
      it "should raise cartridge not found exception when no apps exist" do
        expect { run }.should raise_error RHC::ApplicationNotFoundException
      end
    end
  end


  describe 'app actions' do

    before(:each) do
      @rc = MockRestClient.new
      domain = @rc.add_domain("mockdomain")
      app = domain.add_application("app1", "mock_type")
      app.add_cartridge('mock_cart-1')
    end

    context 'app start' do
      let(:arguments) { ['app', 'start', '-a', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      it { run_output.should match('start') }
    end

    context 'app stop' do
      let(:arguments) { ['app', 'stop', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

      it { run_output.should match('stop') }
    end

    context 'app force stop' do
      let(:arguments) { ['app', 'force-stop', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

      it { run_output.should match('force') }
    end

    context 'app restart' do
      let(:arguments) { ['app', 'restart', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      it { run_output.should match('restart') }
    end

    context 'app reload' do
      let(:arguments) { ['app', 'reload', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      it { run_output.should match('reload') }
    end

    context 'app tidy' do
      let(:arguments) { ['app', 'tidy', 'app1','--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      it { run_output.should match('cleaned') }
    end
  end
end
