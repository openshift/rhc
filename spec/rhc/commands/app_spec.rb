require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/app'
require 'rhc/config'
require 'rhc/servers'
require 'resolv'

describe RHC::Commands::App do
  let!(:rest_client){ MockRestClient.new }
  let!(:config){ user_config }
  before{ RHC::Config.stub(:home_dir).and_return('/home/mock_user') }
  before{ RHC::Servers.stub(:home_dir).and_return('/home/mock_user') }
  before do
    FakeFS.activate!
    FakeFS::FileSystem.clear
    RHC::Helpers.send(:remove_const, :MAX_RETRIES) rescue nil
    RHC::Helpers.const_set(:MAX_RETRIES, 3)
    @instance = RHC::Commands::App.new
    RHC::Commands::App.stub(:new) do
      @instance.stub(:git_config_get) { "" }
      @instance.stub(:git_config_set) { "" }
      Kernel.stub(:sleep) { }
      @instance.stub(:git_clone_repo) do |git_url, repo_dir|
        $terminal.instance_variable_get(:@output).puts "Cloning into..."
        raise RHC::GitException, "Error in git clone" if repo_dir == "giterrorapp"
        Dir::mkdir(repo_dir)
        File.expand_path(repo_dir)
      end
      @instance.stub(:host_exists?) do |host|
        host.match("dnserror") ? false : true
      end
      @instance
    end
  end

  after(:each) do
    FakeFS.deactivate!
  end

  describe 'app default' do
    before do
      FakeFS.deactivate!
    end

    context 'app' do
      let(:arguments) { ['app'] }
      it { run_output.should match('Usage:') }
      it { run_output.should match('List of Actions') }
      it { run_output.should_not match('Options') }
    end
  end

  describe '#gear_group_state' do
    it("shows single state"){ subject.send(:gear_group_state, ['started']).should == 'started' }
    it("shows unique states"){ subject.send(:gear_group_state, ['idle', 'idle']).should == 'idle' }
    it("shows number of started"){ subject.send(:gear_group_state, ['started', 'idle']).should == '1/2 started' }
  end

  describe '#check_domain!' do
    let(:rest_client){ double('RestClient') }
    let(:domain){ double('Domain', :name => 'test') }
    before{ subject.stub(:rest_client).and_return(rest_client) }
    let(:interactive){ false }
    before{ subject.stub(:interactive?).and_return(interactive) }

    context "when no options are provided and there is one domain" do
      before{ rest_client.should_receive(:domains).twice.and_return([domain]) }
      it("should load the first domain"){ subject.send(:check_domain!).should == domain }
      after{ subject.send(:options).namespace.should == domain.name }
    end

    context "when no options are provided and there are no domains" do
      before{ rest_client.should_receive(:domains).and_return([]) }
      it("should load the first domain"){ expect{ subject.send(:check_domain!) }.to raise_error(RHC::Rest::DomainNotFoundException) }
      after{ subject.send(:options).namespace.should be_nil }
    end

    context "when valid namespace is provided" do
      before{ subject.send(:options)[:namespace] = 'test' }
      before{ rest_client.should_receive(:find_domain).with('test').and_return(domain) }
      it("should load the requested domain"){ subject.send(:check_domain!).should == domain }
      after{ subject.send(:options).namespace.should == 'test' }
    end

    context "when interactive and no domains" do
      let(:interactive){ true }
      before{ rest_client.should_receive(:domains).twice.and_return([]) }
      before{ RHC::DomainWizard.should_receive(:new).and_return(double(:run => true)) }
      it("should raise if the wizard doesn't set the option"){ expect{ subject.send(:check_domain!) }.to raise_error(RHC::Rest::DomainNotFoundException) }
      after{ subject.send(:options).namespace.should be_nil }
    end
  end

  describe 'app create' do
    before{ rest_client.add_domain("mockdomain") }

    context "when we ask for help with the alias" do
      before{ FakeFS.deactivate! }
      context do
        let(:arguments) { ['help', 'create-app'] }
        it{ run_output.should match "Usage: rhc app-create <name>" }
      end
      context do
        let(:arguments) { ['create-app', '-h'] }
        it{ run_output.should match "Usage: rhc app-create <name>" }
      end
    end

    context "when run with no arguments" do
      before{ FakeFS.deactivate! }
      let(:arguments){ ['create-app'] }
      it{ run_output.should match "Usage: rhc app-create <name>" }
      it{ run_output.should match "When creating an application, you must provide a name and a cartridge from the list below:" }
      it{ run_output.should match "mock_standalone_cart-1" }
      it{ run_output.should match "Please specify the name of the application" }
    end

    context "when dealing with config" do
      subject{ described_class.new(Commander::Command::Options.new(options)) }
      let(:wizard){ s = double('Wizard'); RHC::EmbeddedWizard.should_receive(:new).and_return(s); s }
      let(:options){ nil }
      let(:interactive){ true }
      before{ subject.should_receive(:interactive?).at_least(1).times.and_return(interactive) }
      before{ subject.stub(:check_sshkeys!) }

      it("should run the wizard"){ expect{ subject.create('name', ['mock_standalone_cart-1']) }.to call(:run).on(wizard).and_stop }

      context "when has config" do
        let(:options){ {:server => 'test', :rhlogin => 'foo'} }
        before{ subject.send(:config).should_receive(:has_local_config?).and_return(true) }
        it("should not run the wizard"){ expect{ subject.create('name', ['mock_standalone_cart-1']) }.to not_call(:new).on(RHC::EmbeddedWizard) }
      end

      context "when has no config" do
        before{ subject.send(:config).should_receive(:has_local_config?).and_return(false) }
        it("should run the wizard"){ expect{ subject.create('name', ['mock_standalone_cart-1']) }.to call(:new).on(RHC::EmbeddedWizard).and_stop }
      end

      context "when not interactive" do
        let(:interactive){ false }
        it("should not run the wizard"){ expect{ subject.create('name', ['mock_standalone_cart-1']) }.to not_call(:new).on(RHC::EmbeddedWizard) }
      end
    end

    context "when dealing with ssh keys" do
      before(:all){ mock_terminal }
      subject{ described_class.new(options) }
      let(:wizard){ s = double('Wizard'); RHC::SSHWizard.should_receive(:new).and_return(s); s }
      let(:options){ Commander::Command::Options.new(:server => 'foo.com', :rhlogin => 'test') }
      let(:interactive){ true }
      before{ subject.should_receive(:interactive?).at_least(1).times.and_return(interactive) }
      before{ subject.should_receive(:check_config!) }

      it("should run the wizard"){ expect{ subject.create('name', ['mock_standalone_cart-1']) }.to call(:run).on(wizard).and_stop }

      context "when not interactive" do
        let(:interactive){ false }
        it("should not run the wizard"){ expect{ subject.create('name', ['mock_standalone_cart-1']) }.to not_call(:new).on(RHC::SSHWizard) }
      end
    end

    context "when in full interactive mode with no keys, domain, or config" do
      let!(:config){ base_config }
      before{ RHC::Config.any_instance.stub(:has_local_config?).and_return(false) }
      before{ described_class.any_instance.stub(:interactive?).and_return(true) }
      before{ described_class.any_instance.stub(:discover_git_executable).and_return('git') }
      before{ rest_client.domains.clear }
      before{ rest_client.sshkeys.delete_if {|k| !k.is_ssh? } }
      let(:arguments) { ['app', 'create', 'app1', 'mock_standalone_cart-1'] }
      # skips login stage and insecure check because of mock rest client, doesn't check keys
      it { run_output(['mydomain', 'y', 'mykey']).should match(/This wizard.*Checking for a domain.*You will not be able to create an application without completing this step.*Your domain 'mydomain' has been successfully created.*Creating application.*Your public SSH key.*Uploading key 'mykey'.*Your application 'app1' is now available.*Cloned to/m) }
    end

    context 'when run without a cart' do
      before{ FakeFS.deactivate! }
      let(:arguments) { ['app', 'create', 'app1'] }
      it { run_output.should match(/mock_standalone_cart-1.*Every application needs a web cartridge/m) }
    end

    context 'when run with a valid cart' do
      let(:arguments) { ['app', 'create', 'app1', 'mock_standalone_cart-1'] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match("Success") }
      it { run_output.should match("Cartridges: mock_standalone_cart-1\n") }
      it { run_output.should_not match(/Environment Variables:/) }
    end

    context 'when Hosts resolver raises an Exception' do
      let(:arguments) { ['app', 'create', 'app1', 'mock_standalone_cart-1'] }
      before :each do
        resolver = Object.new
        Resolv::Hosts.should_receive(:new).and_return(resolver)
        resolver.should_receive(:getaddress).with('app1-mockdomain.fake.foo').and_raise(ArgumentError)
      end

      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match("Success") }
    end

    context 'when run with multiple carts' do
      let(:arguments) { ['app', 'create', 'app1', 'mock_standalone_cart-1', 'mock_cart-1'] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match("Success") }
      it { run_output.should match("Cartridges: mock_standalone_cart-1, mock_cart-1\n") }
      it { run_output.should_not match(/Environment Variables:/) }
      after{ rest_client.domains.first.applications.first.cartridges.find{ |c| c.name == 'mock_cart-1' }.should be_true }
    end

    context 'when run with a cart URL' do
      let(:arguments) { ['app', 'create', 'app1', 'http://foo.com', 'mock_cart-1'] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match("Success") }
      it { run_output.should match("Cartridges: http://foo.com, mock_cart-1\n") }
      it { run_output.should_not match(/Environment Variables:/) }
      after{ rest_client.domains.first.applications.first.cartridges.find{ |c| c.url == 'http://foo.com' }.should be_true }
    end

    context 'when run with a git url' do
      let(:arguments) { ['app', 'create', 'app1', 'mock_standalone_cart-1', '--from-code', 'git://url'] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match("Success") }
      it { run_output.should match("Git remote: git:fake.foo/git/app1.git\n") }
      it { run_output.should match("Source Code: git://url\n") }
      after{ rest_client.domains.first.applications.first.initial_git_url.should == 'git://url' }
    end

    context 'when no cartridges are returned' do
      before do
        domain = rest_client.domains.first
      end
      context 'without trace' do
        let(:arguments) { ['app', 'create', 'app1', 'nomatch_cart'] }
        it("should display the list of cartridges") { run_output.should match(/Short Name.*mock_standalone_cart-2/m) }
      end
      context 'with trace' do
        let(:arguments) { ['app', 'create', 'app1', 'nomatch_cart', '--trace'] }
        it { expect { run }.to raise_error(RHC::CartridgeNotFoundException, "There are no cartridges that match 'nomatch_cart'.") }
      end
    end

  end

  describe 'cart matching behavior' do
    before{ rest_client.add_domain("mockdomain") }

    context 'multiple web matches' do
      let(:arguments) { ['app', 'create', 'app1', 'mock_standalone_cart', '--trace', '--noprompt'] }
      it { expect { run }.to raise_error(RHC::MultipleCartridgesException) }
    end
    context 'when only a single cart can match' do
      let(:arguments) { ['app', 'create', 'app1', 'unique', '--trace', '--noprompt'] }
      it('picks the cart') { run_output.should match('Using mock_unique_standalone_cart-1') }
    end
    context 'when I pick a web cart and an ambiguous non web cart' do
      let(:arguments) { ['app', 'create', 'app1', 'mock_standalone_cart-1', 'unique', '--trace', '--noprompt'] }
      it('picks the non web cart') { run_output.should match('Using unique_mock_cart-1') }
    end
    context 'when I pick very ambiguous carts' do
      let(:arguments) { ['app', 'create', 'app1', 'mock', 'embcart-', '--noprompt'] }
      it('shows only web carts') { run_output.should match("There are multiple cartridges matching 'mock'") }
    end
    context 'when I pick only embedded carts' do
      let(:arguments) { ['app', 'create', 'app1', 'mock_cart', '--trace', '--noprompt'] }
      it { expect { run }.to raise_error(RHC::CartridgeNotFoundException, /Every application needs a web cartridge/) }
    end
    context 'when I pick multiple embedded carts' do
      let(:arguments) { ['app', 'create', 'app1', 'unique_standalone', 'mock_cart', '--trace', '--noprompt'] }
      it { expect { run }.to raise_error(RHC::MultipleCartridgesException, /There are multiple cartridges matching 'mock_cart'/) }
    end
    context 'when I pick multiple standalone carts' do
      let(:arguments) { ['app', 'create', 'app1', 'unique_standalone', 'mock_standalone_cart', '--trace', '--noprompt'] }
      it { expect { run }.to raise_error(RHC::MultipleCartridgesException, /There are multiple cartridges matching 'mock_standalone_cart'/) }
    end
    context 'when I pick a custom URL cart' do
      let(:arguments) { ['app', 'create', 'app1', 'http://foo.com', '--trace', '--noprompt'] }
      it('tells me about custom carts') { run_output.should match("The cartridge 'http://foo.com' will be downloaded") }
      it('lists the cart using the short_name') { run_output.should match(%r(Cartridges:\s+http://foo.com$)) }
    end
    context 'when I pick a custom URL cart and a web cart' do
      let(:arguments) { ['app', 'create', 'app1', 'http://foo.com', 'embcart-1', '--trace', '--noprompt'] }
      it('tells me about custom carts') { run_output.should match("The cartridge 'http://foo.com' will be downloaded") }
      it('lists the carts using the short_name') { run_output.should match(%r(Cartridges:\s+http://foo.com, embcart-1$)) }
    end
  end

  describe 'app create enable-jenkins' do
    let(:arguments) { ['app', 'create', 'app1', '--trace', 'mock_unique_standalone_cart', '--enable-jenkins'] }

    context 'when run' do
      before do
        @domain = rest_client.add_domain("mockdomain")
      end
      it "should create a jenkins app and a regular app with an embedded jenkins client" do
        #puts run_output
        expect { run }.to exit_with_code(0)
        jenkins_app = rest_client.find_application(@domain.name,"jenkins")
        jenkins_app.cartridges[0].name.should == "jenkins-1"
        app = rest_client.find_application(@domain.name,"app1")
        app.find_cartridge("jenkins-client-1")
      end
    end
  end

  describe 'app create enable-jenkins with --no-dns' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--trace', '--enable-jenkins', '--no-dns'] }

    context 'when run' do
      before do
        domain = rest_client.add_domain("mockdomain")
      end
      it { expect { run }.to_not raise_error }
    end
  end

  describe 'app create enable-jenkins with same name as app' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--trace', '--enable-jenkins', 'app1'] }

    context 'when run' do
      before do
        domain = rest_client.add_domain("mockdomain")
      end
      it { expect { run }.to raise_error(ArgumentError, /You have named both your main application and your Jenkins application/) }
    end
  end

  describe 'app create enable-jenkins with existing jenkins' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--trace', '--enable-jenkins', 'jenkins2'] }

    context 'when run' do
      before do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("jenkins", "jenkins-1")
      end
      it "should use existing jenkins" do
        expect { run }.to exit_with_code(0)
        expect { rest_client.find_application(@domain.name,"jenkins") }.to_not raise_error
        expect { rest_client.find_application(@domain.name,"jenkins2") }.to raise_error(RHC::Rest::ApplicationNotFoundException)
      end
    end
  end

  describe 'app create jenkins fails to install warnings' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--enable-jenkins'] }

    before do
      @domain = rest_client.add_domain("mockdomain")
    end

    context 'when run with error in jenkins setup' do
      before do
        @instance.stub(:add_jenkins_app) { raise Exception }
      end
      it "should print out jenkins warning" do
        run_output.should match("Jenkins failed to install")
      end
    end

    context 'when run with error in jenkins-client setup' do
      before do
        @instance.stub(:add_jenkins_cartridge) { raise Exception }
      end
      it "should print out jenkins warning" do
        run_output.should match("Jenkins client failed to install")
      end
    end

    context 'when run without jenkins cartridge available on server' do
      before do
        @instance.stub(:all_cartridges) { rest_client.cartridges.delete_if { |item| item.name =~ /\Ajenkins/i } }
      end
      it "should exit with jenkins error" do
        run_output.should match("There is no installed cartridge that exposes Jenkins")
      end
    end
  end

  describe 'app create jenkins install with retries' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--enable-jenkins'] }

    context 'when run with server error in jenkins-client setup' do
      before do
        @domain = rest_client.add_domain("mockdomain")
        @instance.stub(:add_jenkins_cartridge) { raise RHC::Rest::ServerErrorException.new("Server error", 157) }
      end
      it "should fail embedding jenkins cartridge" do
        Kernel.should_receive(:sleep).and_return(true)
        run_output.should match("Jenkins client failed to install")
      end
    end
  end

  describe 'dns app create warnings' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart'] }

    context 'when run' do
      before do
        @domain = rest_client.add_domain("dnserror")
      end
      it { run_output.should match("unable to lookup your hostname") }
    end
  end

  describe 'app create git warnings' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart'] }

    before do
      @domain = rest_client.add_domain("mockdomain")
      @instance.stub(:git_clone_application) { raise RHC::GitException }
      @instance.stub(:check_sshkeys!)
      @instance.stub(:discover_git_executable).and_return('git')
    end

    context 'when run with error in git clone' do
      it "should print out git warning" do
        run_output.should match("We were unable to clone your application's git repo")
      end
    end

    context 'when run without git installed' do
      before do
        @instance.stub(:has_git?) { false }
      end
      it "should print out git warning" do
        run_output.should match("You do not have git installed")
      end
    end

    context 'when run with windows and no nslookup bug' do
      before do
        RHC::Helpers.stub(:windows?) { true }
        @instance.stub(:run_nslookup) { true }
        @instance.stub(:run_ping) { true }
        @instance.stub(:has_git?) { true }
      end
      it "should print out git warning" do
        run_output.should match(" We were unable to clone your application's git repo")
      end
    end

    context 'when run with windows nslookup bug' do
      before do
        RHC::Helpers.stub(:windows?) { true }
        @instance.stub(:run_nslookup) { true }
        @instance.stub(:run_ping) { false }
        @instance.stub(:has_git?) { true }
      end
      it "should print out windows warning" do
        run_output.should match("This may also be related to an issue with Winsock on Windows")
      end
    end
  end

  describe 'app create prompt for sshkeys' do
    let(:arguments) { ['app', 'create', 'app1', 'mock_unique_standalone_cart', '--config', '/tmp/test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before (:each) do
      @domain = rest_client.add_domain("mockdomain")
      # fakefs is activated
      Dir.mkdir('/tmp/')
      File.open('/tmp/test.conf', 'w') do |f|
        f.write("rhlogin=test@test.foo")
      end

      # don't run wizard here because we test this elsewhere
      wizard_instance = RHC::SSHWizard.new(rest_client, RHC::Config.new, Commander::Command::Options.new)
      wizard_instance.stub(:ssh_key_uploaded?) { true }
      RHC::SSHWizard.stub(:new) { wizard_instance }
      RHC::Config.stub(:should_run_ssh_wizard?) { false }
    end

    context 'when run' do
      it { expect { run }.to exit_with_code(0) }
    end
  end

  describe 'app create from another app' do
    before(:each) do
      FakeFS.deactivate!
      @domain = rest_client.add_domain("mockdomain")
      @app = @domain.add_application("app1", :cartridge=>"mock_standalone_cart-1")
      @app.add_alias('myfoo.com')
      @cart1 = @app.add_cartridge('mock_cart-1')
      @cart2 = @app.add_cartridge('mock_cart-2')
      @cart2.gear_profile = 'medium'
      @instance.stub(:save_snapshot)
      @instance.stub(:restore_snapshot)
      @app.stub(:region){'aRegion'}
      rest_client.api.stub(:supports?).with(:LIST_REGIONS){true} 
    end

    context 'when run and the broker allows region selection' do
      before do
        rest_client.stub(:regions) do
          region = double()
          region.stub(:allow_selection){true}
          [region]
        end
      end

      let(:arguments) { ['app', 'create', 'clone', '--from-app', 'app1', '--no-git'] }
      it { expect { run }.to exit_with_code(0) }
      it "should clone successfully" do
        run_output.should match(/Cartridges:\s+mock_standalone_cart-1, mock_cart-1, mock_cart-2/)
        run_output.should match(/Gear Size:\s+Copied from 'app1'/)
        run_output.should match(/Setting deployment configuration/)
        run_output.should match(/Region:\s+aRegion\s+\(copied from 'app1'/)
        run_output.should match(/done/)
      end
    end

    context 'when source app has a region and the broker does not allow region selection' do

      context 'and region flag is not specified' do
        let(:arguments) { ['app', 'create', 'app2', '--from-app', 'app1', '--no-git'] }
        it "should clone successfully" do
          expect { run }.to exit_with_code(0)
          run_output.should match(/Server does not allow selecting regions.  Region is being ignored./)
          run_output.should match(/Cartridges:\s+mock_standalone_cart-1, mock_cart-1, mock_cart-2/)
          run_output.should match(/Gear Size:\s+Copied from 'app1'/)
          run_output.should_not match(/Region:\s+aRegion\s+\(copied from 'app1'/)
          run_output.should match(/Setting deployment configuration/)
          run_output.should match(/done/)
        end
      end

      context 'and region flag is specified' do
        let(:arguments) { ['app', 'create', 'app2', '--from-app', 'app1', '--region','foo','--no-git'] }
        it "should clone successfully" do
          run_output.should match(/Server does not allow selecting regions.  Region is being ignored./)
          run_output.should match(/Cartridges:\s+mock_standalone_cart-1, mock_cart-1, mock_cart-2/)
          run_output.should match(/Gear Size:\s+Copied from 'app1'/)
          run_output.should_not match(/Region:\s+aRegion\s+\(copied from 'app1'/)
          run_output.should match(/Setting deployment configuration/)
          run_output.should match(/done/)
          expect { run }.to exit_with_code(0)
        end
      end
    end

    context 'when cloning a scalable app as not scalable' do
      before do
        @scaled = @domain.add_application("scaled", "mock_standalone_cart-1", true)
        @scaled.cartridges.each do |c|
          c.scales_from = 2
          c.scales_to = -1
        end
      end
      let(:arguments) { ['app', 'create', 'clone', '--from-app', 'scaled', '--no-git', '--no-scaling'] }
      it "should result in only one gear" do
        expect { run }.to exit_with_code(0)
        @domain.applications.size.should == 3
        @domain.applications.select{|a| a.name == 'clone'}.size.should == 1
        @domain.applications.select{|a| a.name == 'clone'}.first.cartridges.size.should == 1
        @domain.applications.select{|a| a.name == 'clone'}.first.cartridges.first.scales_from.should == 1
        @domain.applications.select{|a| a.name == 'clone'}.first.cartridges.first.scales_to.should == 1
      end
    end

    context 'alias already registered' do
      let(:arguments) { ['app', 'create', 'clone', '--from-app', 'app1', '--no-git'] }
      before do 
        RHC::Rest::Mock::MockRestApplication.any_instance.stub(:aliases).and_return(['www.foo.com'])
      end 
      it { expect { run }.to exit_with_code(0) }
      it "should warn" do
        run_output.should match(/The application 'app1' has aliases set which were not copied/)
      end
    end

    context 'when run against unsupported server' do
      let(:arguments) { ['app', 'create', 'clone', '--from-app', 'app1', '--no-git'] }
      before { @domain.should_receive(:has_param?).with('ADD_APPLICATION','cartridges[][name]').and_return(false) }
      it { expect { run }.to exit_with_code(134) }
      it "should fail" do
        run_output.should match(/The server does not support creating apps based on others/)
      end
    end
  end

  describe 'app delete' do
    let(:arguments) { ['app', 'delete', '--trace', '-a', 'app1', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run' do
      before{ @domain = rest_client.add_domain("mockdomain") }

      it "should raise cartridge not found exception when no apps exist" do
        expect { run }.to raise_error RHC::Rest::ApplicationNotFoundException
      end

      context "with an app" do
        before{ @app = @domain.add_application("app1", "mock_type") }

        it "should not remove app when no is sent as input" do
          expect { run(["no"]) }.to raise_error(RHC::ConfirmationError)
          @domain.applications.length.should == 1
          @domain.applications[0] == @app
        end

        it "should remove app when yes is sent as input" do
          expect { run(["yes"]) }.to exit_with_code(0)
          @domain.applications.length.should == 0
        end

        context "with --noprompt but without --confirm" do
          let(:arguments) { ['app', 'delete', 'app1', '--noprompt', '--trace'] }
          it "should not remove the app" do
            expect { run(["no"]) }.to raise_error(RHC::ConfirmationError)
            @domain.applications.length.should == 1
          end
        end
        context "with --noprompt and --confirm" do
          let(:arguments) { ['app', 'delete', 'app1', '--noprompt', '--confirm'] }
          it "should remove the app" do
            expect { run }.to exit_with_code(0)
            @domain.applications.length.should == 0
          end
        end
      end
    end

    context "against a 1.5 server" do
      let!(:rest_client){ nil }
      let(:username){ mock_user }
      let(:password){ 'password' }
      let(:server){ mock_uri }
      let(:arguments){ ['delete-app', 'foo', '--confirm', '--trace'] }
      before do
        stub_api
        challenge{ stub_one_domain('test') }
        stub_one_application('test', 'foo')
      end
      before do
        stub_api_request(:delete, "broker/rest/domains/test/applications/foo").
          to_return({
            :body   => {
              :type => nil,
              :data => nil,
              :messages => [
                {:exit_code => 0, :field => nil, :severity => 'info', :text => 'Removed foo'},
                {:exit_code => 0, :field => nil, :severity => 'result', :text => 'Job URL changed'},
              ]
            }.to_json,
            :status => 200
          })
      end

      it("should display info returned by the server"){ run_output.should match "Deleting application 'foo'" }
      it("should display results returned by the server"){ run_output.should match "Job URL changed" }
      it('should exit successfully'){ expect{ run }.to exit_with_code(0) }
    end
  end

  describe 'app show' do
    let(:arguments) { ['app', 'show', 'app1'] }

    context 'when run with the same case as created' do
      before do
        FakeFS.deactivate!
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
      end
      it("should output an app") { run_output.should match("app1 @ https://app1-mockdomain.fake.foo/") }
      it { run_output.should match(/Gears:\s+1 small/) }
    end

    context 'when run with scaled app' do
      before do
        @domain = rest_client.add_domain("mockdomain")
        app = @domain.add_application("app1", "mock_type", true)
        cart1 = app.add_cartridge('mock_cart-1')
        cart2 = app.add_cartridge('mock_cart-2')
        cart2.gear_profile = 'medium'
      end
      it { run_output.should match("app1 @ https://app1-mockdomain.fake.foo/") }
      it { run_output.should match(/Scaling:.*x2/) }
      it { run_output.should match(/Gears:\s+Located with mock_type/) }
      it { run_output.should match(/Gears:\s+1 medium/) }
    end

    context 'when run with premium cartridge with single rate' do
      before do
        @domain = rest_client.add_domain("mockdomain")
        app = @domain.add_application("app1", "mock_type", true)
        cart1 = app.add_cartridge('mock_premium_cart-1')
        cart1.usage_rates = {0.01 => []}
      end
      it { run_output.should match(/This cartridge costs an additional \$0.01 per gear after the first 3 gears\./) }
    end

    context 'when run with premium cartridge with multiple rates' do
      before do
        @domain = rest_client.add_domain("mockdomain")
        app = @domain.add_application("app1", "mock_type", true)
        cart1 = app.add_cartridge('mock_premium_cart-2')
        cart1.usage_rates = {0.01 => ['plan1','plan2', 'plan3'], 0.02 => ['plan4'], 0.03 => []}
      end
      it { run_output.should match(/This cartridge costs an additional \$0\.01 per gear after the first 3 gears on the Plan1, Plan2 and Plan3 plans\./) }
      it { run_output.should match(/This cartridge costs an additional \$0\.02 per gear after the first 3 gears on the Plan4 plan\./) }
      it { run_output.should match(/This cartridge costs an additional \$0\.03 per gear after the first 3 gears\./) }
    end

    context 'when run with custom app' do
      before do
        @domain = rest_client.add_domain("mockdomain")
        app = @domain.add_application("app1", "mock_type", true)
        cart1 = app.add_cartridge('mock_cart-1')
        cart1.url = 'https://foo.bar.com'
      end
      it { run_output.should match("app1 @ https://app1-mockdomain.fake.foo/") }
      it { run_output.should match(/Scaling:.*x2/) }
      it { run_output.should match(/Gears:\s+Located with mock_type/) }
      it { run_output.should match(/Gears:\s+1 small/) }
      it { run_output.should match(%r(From:\s+ https://foo.bar.com)) }
    end

    context 'when run with app with custom external cartridges' do
      before do
        @domain = rest_client.add_domain("mockdomain")
        app = @domain.add_application("app1", "mock_type")
        cart1 = app.add_cartridge('mock_cart-1')
        cart1.url = 'https://foo.bar.com'
        cart1.tags = ['external']
        cart1.version = '2'
        cart1.license = 'GPL'
        cart1.website = 'http://bar.com'
        cart1.current_scale = 0
      end
      context 'verbosely' do
        let(:arguments) { ['app', 'show', 'app1', '-v'] }
        it { run_output.should match("app1 @ https://app1-mockdomain.fake.foo/") }
        it { run_output.should match(/Gears:\s+1 small/) }
        it { run_output.should match(/Gears:\s+none \(external service\)/) }
        it { run_output.should match(/Description:\s+Description of mock_cart-1/) }
        it { run_output.should match(%r(Website:\s+ http://bar.com)) }
        it { run_output.should match(/Version:\s+2/) }
        it { run_output.should match(/License:\s+GPL/) }
        it { run_output.should match(%r(From:\s+ https://foo.bar.com)) }
      end
      context 'not verbosely' do
        it { run_output.should match("app1 @ https://app1-mockdomain.fake.foo/") }
        it { run_output.should match(/Gears:\s+1 small/) }
        it { run_output.should match(/Gears:\s+none \(external service\)/) }
        it { run_output.should_not match(/Description:\s+Description of mock_cart-1/) }
        it { run_output.should match(%r(Website:\s+ http://bar.com)) }
        it { run_output.should_not match(/Version:\s+2/) }
        it { run_output.should_not match(/License:\s+GPL/) }
        it { run_output.should match(%r(From:\s+ https://foo.bar.com)) }
      end
    end
  end

  describe 'app show' do
    let(:arguments) { ['app', 'show', 'APP1'] }

    context 'when run with the different case from created' do
      before do
        @rc = MockRestClient.new
        @domain = @rc.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
      end
      it { run_output.should match("app1 @ https://app1-mockdomain.fake.foo/") }
    end
  end

  describe 'app show --state' do
    let(:arguments) { ['app', 'show', 'app1', '--state'] }

    context 'when run' do
      before do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
      end
      it { run_output.should match("started") }
    end
  end

  describe 'app show --gears' do
    context do
      let(:arguments) { ['app', 'show', 'app1', '--gears', '--raw'] }

      context 'when run' do
        before do
          @domain = rest_client.add_domain("mockdomain")
          @domain.add_application("app1", "mock_type")
        end
        it { run_output.should match(/ID\s+State\s+Cartridges\s+Size\s+SSH URL/) }
        it { run_output.should match("fakegearid0 started mock_type  small fakegearid0@fakesshurl.com") }
        it { expect{ run }.to exit_with_code(0) }
      end

      context 'with regions and zones' do
        before do
          @domain = rest_client.add_domain("mockdomain")
          @app = @domain.add_application("app1", "mock_type")
          @app.gears.each{|g| g['region'] = 'south'; g['zone'] = 'west'}
        end
        it { run_output.should match(/ID\s+State\s+Cartridges\s+Size\s+Region\s+Zone\s+SSH URL/) }
        it { run_output.should match(/fakegearid0\s+started\s+mock_type\s+small\s+south\s+west\s+fakegearid0@fakesshurl.com/) }
        it { expect{ run }.to exit_with_code(0) }
      end
    end

    context do
      let(:arguments) { ['app', 'show', 'app1', '--gears'] }

      context 'with cartridge that exposes an endpoint' do
        before do
          @domain = rest_client.add_domain("mockdomain")
          # An application has to be scalable to expose an endpoint.
          @app = @domain.add_application("app1", "mock_type", true)
          @app.gears.first['endpoints'] = [{ 'cartridge_name' => 'mock_cart-1' }]
        end
        it { (run_output.match(/fakegearid0\s+([^\s]+)\s+small\s+fakegearid0@fakesshurl\.com/)[1]).should be_colorized("started", :green) }
      end
    end
  end

  describe 'app show --gears quota' do
    let(:arguments) { ['app', 'show', 'app1', '--gears', 'quota'] }

    context 'when run' do
      before do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type", true)
        expect_multi_ssh('echo "$(du --block-size=1 -s 2>/dev/null | cut -f 1)"', 'fakegearid0@fakesshurl.com' => '1734334', 'fakegearid1@fakesshurl.com' => '1934348')
      end
      it { run_output.should match(/Gear.*Cartridges.*Used.*fakegearid0.*1\.7 MB.*1 GB.*fakegearid1.*1\.9 MB/m) }
      it { expect{ run }.to exit_with_code(0) }
    end
  end

  describe 'app show --gears ssh' do
    let(:arguments) { ['app', 'show', 'app1', '--gears', 'ssh'] }

    context 'when run' do
      before do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type", true)
      end
      it { run_output.should == "fakegearid0@fakesshurl.com\nfakegearid1@fakesshurl.com\n\n" }
      it { expect{ run }.to exit_with_code(0) }
    end
  end

  describe 'app show --gears badcommand' do
    let(:arguments) { ['app', 'show', 'app1', '--gears', 'badcommand'] }

    context 'when run' do
      before{ rest_client.add_domain("mockdomain").add_application("app1", "mock_type", true) }
      it { run_output.should match(/The operation badcommand is not supported/m) }
      it { expect{ run }.to exit_with_code(1) }
    end
  end

  describe 'app actions' do
    before do
      domain = rest_client.add_domain("mockdomain")
      app = domain.add_application("app1", "mock_type")
      app.add_cartridge('mock_cart-1')
    end

    context 'app start' do
      let(:arguments) { ['app', 'start', '-a', 'app1'] }
      it { run_output.should match('start') }
      it { expect{ run }.to exit_with_code(0) }
    end

    context 'app scale-up' do
      let(:arguments) { ['app', 'scale-up', '-a', 'app1'] }
      it { run_output.should match('scaled up') }
      it { expect{ run }.to exit_with_code(0) }
    end

    context 'app scale-down' do
      let(:arguments) { ['app', 'scale-down', '-a', 'app1'] }
      it { run_output.should match('scaled down') }
      it { expect{ run }.to exit_with_code(0) }
    end

    context 'app stop' do
      let(:arguments) { ['app', 'stop', 'app1'] }

      it { run_output.should match('stop') }
      it { expect{ run }.to exit_with_code(0) }
    end

    context 'app force stop' do
      let(:arguments) { ['app', 'force-stop', 'app1'] }

      it { run_output.should match('force') }
      it { expect{ run }.to exit_with_code(0) }
    end

    context 'app restart' do
      let(:arguments) { ['app', 'restart', 'app1'] }
      it { run_output.should match('restart') }
      it { expect{ run }.to exit_with_code(0) }
    end

    context 'app reload' do
      let(:arguments) { ['app', 'reload', 'app1'] }
      it { run_output.should match('reload') }
      it { expect{ run }.to exit_with_code(0) }
    end

    context 'app tidy' do
      let(:arguments) { ['app', 'tidy', 'app1'] }
      it { run_output.should match('cleaned') }
      it { expect{ run }.to exit_with_code(0) }
    end

    context 'app enable-ha' do
      let(:arguments) { ['app', 'enable-ha', 'app1'] }
      it { run_output.should match('is now highly available') }
      it { expect{ run }.to exit_with_code(0) }
    end

  end

  describe 'app enable-ha' do
    before do
      @domain = rest_client.add_domain("mockdomain")
      @app = @domain.add_application("app1", "mock_type")
      @app.add_cartridge('mock_cart-1')
      @app.links.delete 'MAKE_HA'
    end

    let(:arguments) { ['app', 'enable-ha', 'app1'] }

    it "should raise ha not supported exception" do
      run_output.should match(/The server does not support high availability/)
      expect{ run }.to exit_with_code(135)
    end
  end

  describe "#create_app" do
    it("should list cartridges when a server error happens") do
      subject.should_receive(:list_cartridges)
      domain = double
      domain.stub(:add_application).and_raise(RHC::Rest::ValidationException.new('Foo', :cartridges, 109))
      expect{ subject.send(:create_app, 'name', 'jenkins-1', domain) }.to raise_error(RHC::Rest::ValidationException)
    end
  end

  describe 'create app with env vars' do
    before{ @domain = rest_client.add_domain("mockdomain") }

    [['app', 'create', 'app1', 'mock_standalone_cart-1', '-e', 'FOO=BAR'],
     ['app', 'create', 'app1', 'mock_standalone_cart-1', '--env', 'FOO=BAR'],
     ['app', 'create', 'app1', 'mock_standalone_cart-1', 'FOO=BAR']
    ].each_with_index do |args, i|
      context "when run with single env var #{i}" do
        let(:arguments) { args }
        before { @domain.should_receive(:has_param?).with('ADD_APPLICATION','environment_variables').and_return(true) }
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should match("Success") }
        it { run_output.should match(/Cartridges:\s+mock_standalone_cart-1\n/) }
        it { run_output.should match(/Environment Variables:\s+FOO=BAR\n/) }
      end
    end

    [['app', 'create', 'app1', 'mock_standalone_cart-1', '-e', 'VAR1=VAL1', '-e', 'VAR2=VAL2', '-e', 'VAR3=VAL3'],
     ['app', 'create', 'app1', 'mock_standalone_cart-1', '--env', 'VAR1=VAL1', '--env', 'VAR2=VAL2', '--env', 'VAR3=VAL3'],
     ['app', 'create', 'app1', 'mock_standalone_cart-1', 'VAR1=VAL1', 'VAR2=VAL2', 'VAR3=VAL3'],
     ['app', 'create', 'app1', 'mock_standalone_cart-1', 'VAR1=VAL1', 'VAR2=VAL2', '-e', 'VAR3=VAL3'],
     ['app', 'create', 'app1', 'mock_standalone_cart-1', 'VAR1=VAL1', '--env', 'VAR2=VAL2', '-e', 'VAR3=VAL3']
    ].each_with_index do |args, i|
      context "when run with multiple env vars #{i}" do
        let(:arguments) { args }
        before { @domain.should_receive(:has_param?).with('ADD_APPLICATION','environment_variables').and_return(true) }
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should match("Success") }
        it { run_output.should match(/Cartridges:\s+mock_standalone_cart-1\n/) }
        it { run_output.should match(/Environment Variables:\s+VAR1=VAL1, VAR2=VAL2, VAR3=VAL3\n/) }
      end
    end

    [['app', 'create', 'app1', 'mock_standalone_cart-1', '-e', 'FOO=BAR'],
     ['app', 'create', 'app1', 'mock_standalone_cart-1', '--env', 'FOO=BAR'],
     ['app', 'create', 'app1', 'mock_standalone_cart-1', 'FOO=BAR']
    ].each_with_index do |args, i|
      context "when run against a server without env vars support #{i}" do
        let(:arguments) { args }
        before { @domain.should_receive(:has_param?).with('ADD_APPLICATION','environment_variables').and_return(false) }
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should match("Success") }
        it { run_output.should match(/Cartridges:\s+mock_standalone_cart-1\n/) }
        it { run_output.should match("Server does not support environment variables") }
        it { run_output.should_not match(/Environment Variables:\s+FOO=BAR\n/) }
      end
    end

    [['app', 'create', 'app1', 'mock_standalone_cart-1', '-e', 'FOOBAR'],
     ['app', 'create', 'app1', 'mock_standalone_cart-1', '--env', 'FOOBAR'],
     ['app', 'create', 'app1', 'mock_standalone_cart-1', '-eFOOBAR']
    ].each_with_index do |args, i|
      context "when run with syntactically incorrect env vars #{i}" do
        let(:arguments) { args }
        it { expect { run }.to exit_with_code(159) }
        it { run_output.should match(/Environment variable\(s\) not provided.\nPlease provide at least one environment variable using the syntax VARIABLE=VALUE\. VARIABLE can only contain letters, digits and underscore \('_'\) and can't begin with a digit\./) }
      end
    end

  end

  describe "configure app" do
    deployment_app_name = 'mock_app_deploy'

    before do
      @rest_app = rest_client.add_domain("mock_domain").add_application(deployment_app_name, 'ruby-1.8.7')
      @rest_app.stub(:ssh_url).and_return("ssh://user@test.domain.com")
    end

    context "manual deployment keeping a history of 10" do
      let(:arguments) {['app', 'configure', '--app', deployment_app_name, '--no-auto-deploy', '--keep-deployments', '10']}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Configuring application '#{deployment_app_name}' .../)
        run_output.should match(/done/)
        @rest_app.auto_deploy.should == false
        @rest_app.keep_deployments.should == 10
        run_output.should match(/Your application '#{deployment_app_name}' is now configured as listed above/)
      end
    end

    context "with no configuration options" do
      let(:arguments) {['app', 'configure', '--app', deployment_app_name]}
      it "should display the current configuration" do
        expect{ run }.to exit_with_code(0)
        run_output.should_not match(/Configuring application '#{deployment_app_name}' .../)
        run_output.should_not match(/done/)
        run_output.should match(/Your application '#{deployment_app_name}' is configured as listed above/)
      end
    end
  end

  describe 'deploy' do
    deployment_app_name = 'mock_app_deploy'

    before do
      FakeFS.deactivate!
      @rest_app = rest_client.add_domain("mock_domain").add_application(deployment_app_name, 'ruby-1.8.7')
      @rest_app.stub(:ssh_url).and_return("ssh://user@test.domain.com")
      @targz_filename = File.dirname(__FILE__) + '/' + deployment_app_name + '.tar.gz'
      FileUtils.cp(File.expand_path('../../assets/targz_sample.tar.gz', __FILE__), @targz_filename)
      File.chmod 0644, @targz_filename unless File.executable? @targz_filename
    end


    context "git ref successfully" do
      before { Net::SSH.should_receive(:start).exactly(3).times.with('test.domain.com', 'user', :compression=>false) }
      let(:arguments) {['app', 'deploy', 'master', '--app', deployment_app_name]}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Deployment of git ref 'master' in progress for application #{deployment_app_name} .../)
        run_output.should match(/Success/)
      end
    end

    context "git ref successfully with custom ssh executable" do
      ssh_path = '/usr/bin/ssh'

      let(:arguments) {['app', 'deploy', 'master', '--app', deployment_app_name, '--ssh', ssh_path]}
      it "should succeed" do
        @instance.should_receive(:check_ssh_executable!).at_least(:once).and_return(ssh_path)
        @instance.should_receive(:run_with_system_ssh).at_least(:once)
        @instance.stub(:exec).and_return([0, "success"])
        run_output.should match(/Deployment of git ref 'master' in progress for application #{deployment_app_name} .../)
        run_output.should match(/Success/)
        expect{ run }.to exit_with_code(0)
      end
    end

    context "binary file successfully" do
      before do
        @rest_app.stub(:deployment_type).and_return('binary')
        ssh = double(Net::SSH)
        session = double(Net::SSH::Connection::Session)
        channel = double(Net::SSH::Connection::Channel)
        exit_status = double(Net::SSH::Buffer)
        exit_status.stub(:read_long).and_return(0)
        Net::SSH.should_receive(:start).exactly(3).times.with('test.domain.com', 'user', :compression=>false).and_yield(session)
        session.should_receive(:open_channel).exactly(3).times.and_yield(channel)
        channel.should_receive(:exec).exactly(3).times.with("oo-binary-deploy").and_yield(nil, nil)
        channel.should_receive(:on_data).exactly(3).times.and_yield(nil, 'foo')
        channel.should_receive(:on_extended_data).exactly(3).times.and_yield(nil, nil, '')
        channel.should_receive(:on_close).exactly(3).times.and_yield(nil)
        channel.should_receive(:on_request).exactly(3).times.with("exit-status").and_yield(nil, exit_status)
        lines = ''
        File.open(@targz_filename, 'rb') do |file|
          file.chunk(1024) do |chunk|
            lines << chunk
          end
        end
        channel.should_receive(:send_data).exactly(3).times.with(lines)
        channel.should_receive(:eof!).exactly(3).times
        session.should_receive(:loop).exactly(3).times
      end
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', deployment_app_name]}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Deployment of file '#{@targz_filename}' in progress for application #{deployment_app_name} .../)
        run_output.should match(/Success/)
      end
    end

    [URI('http://foo.com/path/to/file/' + deployment_app_name + '.tar.gz'),
     URI('https://foo.com/path/to/file/' + deployment_app_name + '.tar.gz')].each do |uri|
      context "url file successfully" do
        before do
        @rest_app.stub(:deployment_type).and_return('binary')
          ssh = double(Net::SSH)
          session = double(Net::SSH::Connection::Session)
          channel = double(Net::SSH::Connection::Channel)
          exit_status = double(Net::SSH::Buffer)
          exit_status.stub(:read_long).and_return(0)
          Net::SSH.should_receive(:start).exactly(3).times.with('test.domain.com', 'user', :compression=>false).and_yield(session)
          session.should_receive(:open_channel).exactly(3).times.and_yield(channel)
          channel.should_receive(:exec).exactly(3).times.with("oo-binary-deploy").and_yield(nil, nil)
          channel.should_receive(:on_data).exactly(3).times.and_yield(nil, 'foo')
          channel.should_receive(:on_extended_data).exactly(3).times.and_yield(nil, nil, '')
          channel.should_receive(:on_close).exactly(3).times.and_yield(nil)
          channel.should_receive(:on_request).exactly(3).times.with("exit-status").and_yield(nil, exit_status)
          lines = ''
          File.open(@targz_filename, 'rb') do |file|
            file.chunk(1024) do |chunk|
              lines << chunk
            end
          end
          stub_request(:get, uri.to_s).to_return(:status => 200, :body => lines, :headers => {})
          channel.should_receive(:send_data).exactly(3).times.with(lines)
          channel.should_receive(:eof!).exactly(3).times
          session.should_receive(:loop).exactly(3).times
        end
        let(:arguments) {['app', 'deploy', uri.to_s, '--app', deployment_app_name]}
        it "should succeed" do
          expect{ run }.to exit_with_code(0)
          run_output.should match(/Deployment of file '#{uri.to_s}' in progress for application #{deployment_app_name} .../)
          run_output.should match(/Success/)
        end
      end
    end

    context "binary file successfully with ssh executable" do
      ssh_path = '/usr/bin/ssh'
      before do
        base_config { |c, d| d.add 'ssh', ssh_path }
        @rest_app.stub(:deployment_type).and_return('binary')
        @instance.stub(:exec).and_return([0, "success"])
      end
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', deployment_app_name]}
      it "should succeed" do
        @instance.should_receive(:run_with_system_ssh).with(/cat #{@targz_filename} \|/).at_least(:once)
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Deployment of file '#{@targz_filename}' in progress for application #{deployment_app_name} .../)
        run_output.should match(/Success/)
      end
    end

    context "binary file successfully with ssh executable on windows" do
      ssh_path = 'C:\Program Files\openSSH\ssh.exe'
      before do
        base_config { |c, d| d.add 'ssh', ssh_path }
        @instance.stub(:check_ssh_executable!).and_return(ssh_path)
        @instance.stub(:windows?).and_return('true')
        @rest_app.stub(:deployment_type).and_return('binary')
        @instance.stub(:run_with_system_ssh).and_return([0, "success"])
      end
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', deployment_app_name]}
      it "should succeed" do
        @instance.should_receive(:run_with_system_ssh).with(/type #{@targz_filename} \|/).at_least(:once)
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Deployment of file '#{@targz_filename}' in progress for application #{deployment_app_name} .../)
        run_output.should match(/Success/)
      end
    end

    context "binary file from url successfully with ssh executable" do
      ssh_path = '/usr/bin/ssh'
      file_url = "http://example.com#{@targz_filename}"
      before do
        base_config { |c, d| d.add 'ssh', ssh_path }
        @rest_app.stub(:deployment_type).and_return('binary')
        @instance.stub(:run_with_system_ssh).and_return([0, "success"])
      end
      let(:arguments) {['app', 'deploy', file_url, '--app', deployment_app_name]}
      it "should succeed" do
        expect{ run }.to exit_with_code(0)
        run_output.should match(/Deployment of file '#{file_url}' in progress for application #{deployment_app_name} .../)
        run_output.should match(/Success/)
      end
    end

    context "binary file with corrupted file" do
      before do
        @rest_app.stub(:deployment_type).and_return('binary')
        ssh = double(Net::SSH)
        session = double(Net::SSH::Connection::Session)
        channel = double(Net::SSH::Connection::Channel)
        exit_status = double(Net::SSH::Buffer)
        exit_status.stub(:read_long).and_return(255)
        Net::SSH.should_receive(:start).exactly(3).times.with('test.domain.com', 'user', :compression=>false).and_yield(session)
        session.should_receive(:open_channel).exactly(3).times.and_yield(channel)
        channel.should_receive(:exec).exactly(3).times.with("oo-binary-deploy").and_yield(nil, nil)
        channel.should_receive(:on_data).exactly(3).times.and_yield(nil, 'foo')
        channel.should_receive(:on_extended_data).exactly(3).times.and_yield(nil, nil, 'Invalid file')
        channel.should_receive(:on_close).exactly(3).times.and_yield(nil)
        channel.should_receive(:on_request).exactly(3).times.with("exit-status").and_yield(nil, exit_status)
        lines = ''
        File.open(@targz_filename, 'rb') do |file|
          file.chunk(1024) do |chunk|
            lines << chunk
          end
        end
        channel.should_receive(:send_data).exactly(3).times.with(lines)
        channel.should_receive(:eof!).exactly(3).times
        session.should_receive(:loop).exactly(3).times
      end
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', deployment_app_name]}
      it "should not succeed" do
        expect{ run }.to exit_with_code(133)
        run_output.should match(/Deployment of file '#{@targz_filename}' in progress for application #{deployment_app_name} .../)
        run_output.should match(/Invalid file/)
      end
    end

    context "fails when deploying git ref" do
      before (:each) { Net::SSH.should_receive(:start).and_raise(Errno::ECONNREFUSED) }
      let(:arguments) {['app', 'deploy', 'master', '--app', deployment_app_name]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end

    context "fails when deploying git ref with custom ssh executable" do
      ssh_path = '/usr/bin/ssh'
      before do
        base_config { |c, d| d.add 'ssh', ssh_path }
      end
      let(:arguments) {['app', 'deploy', 'master', '--app', deployment_app_name]}
      it "should exit with ssh command output" do
        @instance.stub(:exec).and_return([1, "FAILURE"])
        expect{ run }.to exit_with_code(133)
        run_output.should match(/FAILURE/)
        run_output.should match(/Error deploying git ref\. You can try to deploy manually with/)
      end
    end

    context "fails when deploying binary file" do
      before (:each) do
        @rest_app.stub(:deployment_type).and_return('binary')
        Net::SSH.should_receive(:start).and_raise(Errno::ECONNREFUSED)
      end
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', deployment_app_name]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end

    context "fails when deploying binary file" do
      before (:each) do
        @rest_app.stub(:deployment_type).and_return('binary')
        Net::SSH.should_receive(:start).and_raise(SocketError)
      end
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', deployment_app_name]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end

    context "fails when deploying url file" do
      before (:each) do
        @rest_app.stub(:deployment_type).and_return('binary')
        Net::SSH.should_receive(:start).and_raise(Errno::ECONNREFUSED)
      end
      let(:arguments) {['app', 'deploy', 'http://foo.com/deploy.tar.gz', '--app', deployment_app_name]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end

    context "fails when deploying url file" do
      before (:each) do
        @rest_app.stub(:deployment_type).and_return('binary')
        Net::SSH.should_receive(:start).and_raise(SocketError)
      end
      let(:arguments) {['app', 'deploy', 'http://foo.com/deploy.tar.gz', '--app', deployment_app_name]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
      end
    end

    context 'when run against an unsupported server' do
      before {
        @rest_app.links.delete 'UPDATE'
        @rest_app.links.delete 'DEPLOY'
      }
      let(:arguments) {['app', 'deploy', 'master', '--app', deployment_app_name]}
      it "should raise not supported exception" do
        expect{ run }.to exit_with_code(132)
        run_output.should match(/The server does not support deployments/)
      end
    end

    context "ssh authentication failure" do
      before (:each) { Net::SSH.should_receive(:start).exactly(2).times.and_raise(Net::SSH::AuthenticationFailed) }
      let(:arguments) {['app', 'deploy', 'master', '--app', deployment_app_name]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(1)
        run_output.should match(/Authentication to server test.domain.com with user user failed/)
      end
    end

    context "fails when deploying git reference on an app configured to deployment_type = binary" do
      before { @rest_app.stub(:deployment_type).and_return('binary') }
      let(:arguments) {['app', 'deploy', 'master', '--app', deployment_app_name]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(133)
      end
    end

    context "fails when deploying file on an app configured to deployment_type = git" do
      before { @rest_app.stub(:deployment_type).and_return('git') }
      let(:arguments) {['app', 'deploy', @targz_filename, '--app', deployment_app_name]}
      it "should exit with error" do
        expect{ run }.to exit_with_code(133)
      end
    end

    [URI('http://foo.com/path/to/file/' + deployment_app_name + '.tar.gz'),
     URI('https://foo.com/path/to/file/' + deployment_app_name + '.tar.gz')].each do |uri|
      context "fails when deploying url on an app configured to deployment_type = git" do
        before { @rest_app.stub(:deployment_type).and_return('git') }
        let(:arguments) {['app', 'deploy', uri.to_s, '--app', deployment_app_name]}
        it "should exit with error" do
          expect{ run }.to exit_with_code(133)
        end
      end
    end

  end


end
