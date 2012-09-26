require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/app'
require 'rhc/config'

describe RHC::Commands::App do
  before(:each) do
    FakeFS.activate!
    RHC::Config.set_defaults
    @instance = RHC::Commands::App.new
    RHC::Commands::App.stub(:new) do
      @instance.stub(:git_config_get) { "" }
      @instance.stub(:git_config_set) { "" }
      Kernel.stub(:sleep) { }
      @instance.stub(:git_clone_repo) do |git_url, repo_dir|
        raise RHC::GitException, "Error in git clone" if repo_dir == "giterrorapp"
        Dir::mkdir(repo_dir)
      end
      @instance.stub(:host_exist?) do |host|
        host.match("dnserror") ? false : true
      end
      @instance
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

  describe 'app create jenkins fails to install warnings' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--enable-jenkins', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
      @rc = MockRestClient.new
      @domain = @rc.add_domain("mockdomain")
    end

    context 'when run with error in jenkins setup' do
      before(:each) do
        @instance.stub(:setup_jenkins_app) { raise Exception }
      end
      it "should print out jenkins warning" do
        run_output.should match("Jenkins failed to install")
      end
    end

    context 'when run with error in jenkins-client setup' do
      before(:each) do
        @instance.stub(:setup_jenkins_client) { raise Exception }
      end
      it "should print out jenkins warning" do
        run_output.should match("Jenkins client failed to install")
      end
    end
  end

  describe 'dns app create warnings' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        @domain = @rc.add_domain("dnserror")
      end
      it { run_output.should match("unable to lookup your hostname") }
    end
  end

  describe 'app create git warnings' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
      @rc = MockRestClient.new
      @domain = @rc.add_domain("mockdomain")
      @instance.stub(:run_git_clone) { raise RHC::GitException }
    end

    context 'when run with error in git clone' do
      it "should print out git warning" do
        run_output.should match("We were unable to clone your application's git repo")
      end
    end

    context 'when run with windows and no nslookup bug' do
      before(:each) do
        RHC::Helpers.stub(:windows?) { true }
        @instance.stub(:run_nslookup) { true }
        @instance.stub(:run_ping) { true }
      end
      it "should print out git warning" do
        run_output.should match(" We were unable to clone your application's git repo")
      end
    end

    context 'when run with windows nslookup bug' do
      before(:each) do
        RHC::Helpers.stub(:windows?) { true }
        @instance.stub(:run_nslookup) { true }
        @instance.stub(:run_ping) { false }
      end
      it "should print out windows warning" do
        run_output.should match("This may also be related to an issue with Winsock on Windows")
      end
    end
  end

  describe 'app create --nogit deprecated' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--noprompt', '--nogit', '--config', '/tmp/test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before (:each) do
      @rc = MockRestClient.new
      @domain = @rc.add_domain("mockdomain")
    end

    context 'when run' do
      it { run_output.should match("The option '--nogit' is deprecated. Please use '--\\[no-\\]git' instead") }
    end
  end

  describe 'app create prompt for sshkeys' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--config', '/tmp/test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before (:each) do
      @rc = MockRestClient.new
      @domain = @rc.add_domain("mockdomain")
      # fakefs is activated
      Dir.mkdir('/tmp/')
      File.open('/tmp/test.conf', 'w') do |f|
        f.write("rhlogin=test@test.foo")
      end

      # don't run wizard here because we test this elsewhere
      wizard_instance = RHC::SSHWizard.new(@rc)
      wizard_instance.stub(:ssh_key_uploaded?) { true }
      RHC::SSHWizard.stub(:new) { wizard_instance }
      RHC::Config.stub(:should_run_ssh_wizard?) { false }
    end

    context 'when run' do
      it { expect { run }.should exit_with_code(0) }
    end
  end

  describe 'app git-clone' do
    let(:arguments) { ['app', 'git-clone', '--trace', '-a', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        @domain = @rc.add_domain("mockdomain")
        @app = @domain.add_application("app1", "mock_unique_standalone_cart")
      end
      it { expect { run }.should exit_with_code(0) }
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

  describe 'app show' do
    let(:arguments) { ['app', 'show', 'app1', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before(:each) do
        @rc = MockRestClient.new
        @domain = @rc.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
      end
      it { run_output.should match("app1 @ https://app1-mockdomain.fake.foo/") }
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
