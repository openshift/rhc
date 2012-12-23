require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/wizard'
require 'rhc/vendor/parseconfig'
require 'rhc/config'
require 'ostruct'
require 'rest_spec_helper'

# Allow to define the id method
OpenStruct.__send__(:define_method, :id) { @table[:id] } if RUBY_VERSION.to_f == 1.8

describe RHC::Wizard do

  def mock_config
    RHC::Config.stub(:home_dir).and_return('/home/mock_user')
  end

  describe "#login_stage" do
    let(:options){ (o = Commander::Command::Options.new).default(default_options); o }
    let(:config){ RHC::Config.new.tap{ |c| c.stub(:home_dir).and_return('/home/mock_user') } }
    let(:default_options){ {} }
    let(:user){ 'test_user' }
    let(:password){ 'test pass' }
    let(:rest_client){ stub }

    subject{ RHC::Wizard.new(config, options) }

    def expect_client_test
      subject.should_receive(:new_client_for_options).ordered.and_return(rest_client)
      rest_client.should_receive(:api).ordered
      rest_client.should_receive(:user).ordered.and_return(true)
    end
    def expect_raise_from_api(error)
      subject.should_receive(:say).with("Using #{user} to login to openshift.redhat.com").ordered
      subject.should_receive(:new_client_for_options).ordered.and_return(rest_client)
      rest_client.should_receive(:api).ordered.and_raise(error)
    end

    it "should prompt for user and password" do
      subject.should_receive(:ask).with("Login to openshift.redhat.com: ").ordered.and_return(user)
      subject.should_receive(:ask).with("Password: ").ordered.and_return(password)
      expect_client_test

      subject.send(:login_stage).should be_true
    end

    context "with credentials" do
      let(:default_options){ {:rhlogin => user, :password => password} }

      it "should warn about a cert error for Online" do
        expect_raise_from_api(RHC::Rest::CertificateVerificationFailed.new('reason', 'message'))
        subject.should_receive(:warn).with(/server's certificate could not be verified/).ordered
        subject.should_receive(:openshift_online_server?).ordered.and_return(true)
        subject.should_receive(:warn).with(/server between you and OpenShift/).ordered

        subject.send(:login_stage).should be_nil
      end

      it "should warn about a cert error for custom server and continue" do
        expect_raise_from_api(RHC::Rest::CertificateVerificationFailed.new('reason', 'message'))
        subject.should_receive(:warn).with(/server's certificate could not be verified/).ordered
        subject.should_receive(:openshift_online_server?).ordered.and_return(false)
        subject.should_receive(:warn).with(/bypass this check/).ordered
        subject.should_receive(:agree).with(/Connect without checking/).ordered.and_return(true)
        expect_client_test

        subject.send(:login_stage).should be_true
        options.insecure.should be_true
      end

      it "should warn about a cert error for custom server and be cancelled" do
        expect_raise_from_api(RHC::Rest::CertificateVerificationFailed.new('reason', 'message'))
        subject.should_receive(:warn).with(/server's certificate could not be verified/).ordered
        subject.should_receive(:openshift_online_server?).ordered.and_return(false)
        subject.should_receive(:warn).with(/bypass this check/).ordered
        subject.should_receive(:agree).with(/Connect without checking/).ordered.and_return(false)

        subject.send(:login_stage).should be_nil
        options.insecure.should be_false
      end
    end
  end

  #TODO: Implement more stage level specs

  context "when the wizard is run" do
    before(:all) do
      mock_terminal
      FakeFS.activate!
      FakeFS::FileSystem.clear
      mock_config
      RHC::Config.initialize
    end

    after(:all) do
      FakeFS.deactivate!
    end

    context "First run of rhc" do
      subject{ FirstRunWizardDriver.new }
      before(:all) do
        mock_config
      end

      #FIXME: Each of these runs must be a single spec (since they have state).
      #  We should be doing a better job of abstracting out the common bits, and
      #  separating initial conditions in the context.  These tests can stub less
      #  than the stage level tests (should use mock rest client and mock files)
      #  but should demonstrate whole wizard execution.
      #
      #  Example:
      #
      #     before{ set stubs and preconditions }
      #     let(:input){ ['y', '', '', ''] }
      #     its(:run){ should be true }
      #     it{ capture{ subject.run }.should ... } # maybe use shared example
      #     after{ expects_mock_file_on_disk; ... }
      #
      it "should print out first run greeting" do
        subject.run_next_stage
        greeting = $terminal.read
        greeting.count("\n").should >= 3
        greeting.should match(/OpenShift Client Tools \(RHC\) Setup Wizard/)
      #end

      #it "should ask for login and hide password input" do
        subject.stub_rhc_client_new
        # queue up input
        $terminal.write_line "#{subject.mock_user}"
        $terminal.write_line "password"


        subject.run_next_stage

        output = $terminal.read
        output.should match("Login to ")
        output.should match(/Password: [\*]{8}$/)
      #end

      #it "should write out a config" do
        File.exists?(subject.config_path).should be false
        subject.run_next_stage
        File.readable?(subject.config_path).should be true
        cp = RHC::Vendor::ParseConfig.new subject.config_path
        cp["default_rhlogin"].should == subject.mock_user
        cp["libra_server"].should == subject.openshift_server
      #end

      #it "should write out generated ssh keys" do
        subject.setup_mock_ssh

        private_key_file = File.join(subject.ssh_dir, "id_rsa")
        public_key_file = File.join(subject.ssh_dir, "id_rsa.pub")
        File.exists?(private_key_file).should be false
        File.exists?(public_key_file).should be false
        subject.run_next_stage
        File.exists?(private_key_file).should be true
        File.exists?(public_key_file).should be true
      #end

      #it "should ask to upload ssh keys" do
        @rest_client.stub(:get_ssh_keys) { subject.get_mock_key_data }
        $terminal.write_line('yes')
        subject.stub_rhc_client_new
        subject.ssh_keys = []
        subject.run_next_stage
      #end

      #it "should check for client tools" do
        subject.setup_mock_has_git(true)
        subject.run_next_stage
        output = $terminal.read
        output.should match(/Checking for git .*found/)
      #end

      #it "should ask for a namespace" do
        $terminal.write_line("thisnamespaceistoobigandhastoomanycharacterstobevalid")

        $terminal.write_line("invalidnamespace")
        $terminal.write_line("testnamespace")
        subject.run_next_stage
        output = $terminal.read
        output.should match(/Checking your namespace .*none/)
      #end

      #it "should show app creation commands" do
        subject.run_next_stage
        output = $terminal.read
        output.should match('rhc app create <app name> mock_standalone_cart-1')
      #end

      #it "should show a thank you message" do
        subject.run_next_stage
        output = $terminal.read
        output.should match("The OpenShift client tools have been configured on your computer")
      end
    end

    context "Repeat run of rhc setup without anything set" do
      subject{ RerunWizardDriver.new }
      before(:all) do
        mock_config
      end

      it "should print out repeat run greeting" do
        subject.run_next_stage
        greeting = $terminal.read
        greeting.should match(/OpenShift Client Tools \(RHC\) Setup Wizard/)
      #end

      #it "should ask for login and hide password input" do
        subject.stub_rhc_client_new
        $terminal.write_line "#{subject.mock_user}"
        $terminal.write_line "password"

        subject.run_next_stage

        output = $terminal.read
        output.should match("Login to ")
        output.should match(/Password: [\*]{8}$/)
      #end

      #it "should write out a config" do
        File.exists?(subject.config_path).should be false
        subject.run_next_stage
        File.readable?(subject.config_path).should be true
        cp = RHC::Vendor::ParseConfig.new subject.config_path
        cp["default_rhlogin"].should == subject.mock_user
        cp["libra_server"].should == subject.openshift_server
      #end

      #it "should write out generated ssh keys" do
        subject.setup_mock_ssh
        subject.should_receive(:ssh_add).once.and_return(true)

        private_key_file = File.join(subject.ssh_dir, "id_rsa")
        public_key_file = File.join(subject.ssh_dir, "id_rsa.pub")
        File.exists?(private_key_file).should be false
        File.exists?(public_key_file).should be false
        subject.run_next_stage
        File.exists?(private_key_file).should be true
        File.exists?(public_key_file).should be true
      #end

      #it "should upload ssh key as default" do
        @rest_client.stub(:sshkeys) {[]}
        subject.stub(:get_preferred_key_name) { 'default' }
        $terminal.write_line('yes')
        subject.run_next_stage
      #end

      #it "should check for client tools and print they need to be installed" do
        subject.setup_mock_has_git(false)
        subject.run_next_stage
        output = $terminal.read
        output.should match(/Checking for git .*needs to be installed/)
        output.should match("Automated installation of client tools is not supported for your platform")
      #end

      #it "should ask for a namespace" do
        $terminal.write_line("testnamespace")
        subject.run_next_stage
        output = $terminal.read
        output.should match(/Checking your namespace .*none/)
      #end

      #it "should show app creation commands" do
        subject.run_next_stage
        output = $terminal.read
        output.should match('rhc app create <app name> mock_standalone_cart-1')
      #end

      #it "should show a thank you message" do
        subject.run_next_stage
        output = $terminal.read
        output.should match("Your client tools are now configured.")
      end
    end

    context "Repeat run of rhc setup with config set" do
      subject{ RerunWizardDriver.new }
      before(:all) do
        mock_config
        subject.setup_mock_config
        subject.run_next_stage # we can skip testing the greeting
      end

      it "should ask for password input with default login" do
        subject.stub_rhc_client_new

        $terminal.write_line("") # hit enter for default
        $terminal.write_line "password"

        subject.run_next_stage

        output = $terminal.read
        output.should match("|#{subject.mock_user}|")
      #end

      #it "should write out a config" do
        File.exists?(subject.config_path).should be true
        subject.run_next_stage
        File.readable?(subject.config_path).should be true
        cp = RHC::Vendor::ParseConfig.new subject.config_path
        cp["default_rhlogin"].should == subject.mock_user
        cp["libra_server"].should == subject.openshift_server
      #end

      #it "should write out generated ssh keys" do
        subject.setup_mock_ssh
        private_key_file = File.join(subject.ssh_dir, "id_rsa")
        public_key_file = File.join(subject.ssh_dir, "id_rsa.pub")
        File.exists?(private_key_file).should be false
        File.exists?(public_key_file).should be false
        subject.run_next_stage
        File.exists?(private_key_file).should be true
        File.exists?(public_key_file).should be true
      #end

      #it "should find out that you have not uploaded the default key and ask to name the key" do
        key_data = subject.get_mock_key_data
        subject.ssh_keys = key_data
        key_name = '73ce2cc1'

        fingerprint, short_name = subject.get_key_fingerprint
        subject.rest_client.stub(:find_key) { key_data.detect{|k| k.name == key_name} }
        $terminal.write_line('yes')
        $terminal.write_line(key_name) # answering with an existing key name
        subject.run_next_stage
        output = $terminal.read
        key_data.each do |key|
          output.should match(/#{key.name} \(type: ssh-rsa\)/)
          output.should match("Fingerprint: #{key.fingerprint}")
        end
        output.should match("|#{short_name}|") # prompt with the default name
      #end

      #it "should check for client tools and find them" do
        subject.setup_mock_has_git(true)
        subject.run_next_stage
        output = $terminal.read
        output.should match(/Checking for git .*found/)
      #end

      #it "should ask for a namespace" do
        $terminal.write_line("testnamespace")
        subject.run_next_stage
        output = $terminal.read
        output.should match(/Checking your namespace .*none/)
      #end

      #it "should show app creation commands" do
        subject.run_next_stage
        output = $terminal.read
        output.should match('rhc app create <app name> mock_standalone_cart-1')
      #end

      #it "should show a thank you message" do
        subject.run_next_stage
        output = $terminal.read
        output.should match("Your client tools are now configured")
      end
    end

    context "Repeat run of rhc setup with config and ssh keys set" do
      subject{ RerunWizardDriver.new }
      before(:all) do
        mock_config
        subject.setup_mock_config
        subject.setup_mock_ssh(true)
        subject.run_next_stage # we can skip testing the greeting
      end

      it "should ask for password input with default login" do
        subject.stub_rhc_client_new

        $terminal.write_line("") # hit enter for default
        $terminal.write_line "password"

        subject.run_next_stage

        output = $terminal.read
        output.should match("|#{subject.mock_user}|")
      #end

      #it "should write out a config" do
        File.exists?(subject.config_path).should be true
        subject.run_next_stage
        File.readable?(subject.config_path).should be true
        cp = RHC::Vendor::ParseConfig.new subject.config_path
        cp["default_rhlogin"].should == subject.mock_user
        cp["libra_server"].should == subject.openshift_server
      #end

      #it "should check for ssh keys and find a match" do
        subject.stub(:ssh_key_uploaded?) { true } # an SSH key already exists
        subject.run_next_stage # key config is pretty much a noop here

        # run the key check stage
        subject.run_next_stage

        output = $terminal.read
        output.should_not match("ssh key must be uploaded")
      #end

      #it "should check for client tools and find them" do
        subject.setup_mock_has_git(true)
        subject.run_next_stage
        output = $terminal.read
        output.should match(/Checking for git .*found/)
      #end

      #it "should ask for a namespace" do
        $terminal.write_line("testnamespace")
        subject.run_next_stage
        output = $terminal.read
        output.should match(/Checking your namespace .*none/)
      #end

      #it "should show app creation commands" do
        subject.run_next_stage
        output = $terminal.read
        output.should match('rhc app create <app name> mock_standalone_cart-1')
      #end

      #it "should show a thank you message" do
        subject.run_next_stage
        output = $terminal.read
        output.should match("Your client tools are now configured")
      end
    end

    context "Repeat run of rhc setup with everything set" do
      subject{ RerunWizardDriver.new }
      before(:all) do
        mock_config
        @namespace = 'testnamespace'
        @rest_client = RestSpecHelper::MockRestClient.new
        domain = @rest_client.add_domain(@namespace)
        domain.add_application('test1', 'mock_standalone_cart-1')
        domain.add_application('test2', 'mock_standalone_cart-2')
        subject.setup_mock_config("old_mock_user@bar.baz")
        subject.setup_mock_ssh(true)
        subject.setup_mock_domain_and_applications(@namespace, 'test1' => :default, 'test2' => :default)
        subject.run_next_stage # we can skip testing the greeting
      end

      it "should ask password input with default login(use a different one)" do
        $terminal.write_line(subject.mock_user)
        $terminal.write_line "password"

        subject.run_next_stage

        output = $terminal.read
        output.should match("|old_mock_user@bar.baz|")
      #end

      #it "should write out a config" do
        File.exists?(subject.config_path).should be true
        subject.run_next_stage
        File.readable?(subject.config_path).should be true
        cp = RHC::Vendor::ParseConfig.new subject.config_path
        cp["default_rhlogin"].should == subject.mock_user
        cp["libra_server"].should == subject.openshift_server
      #end

      #it "should check for ssh keys, not find it on the server and update existing key" do
        key_data = subject.get_mock_key_data
        key_data.delete_if { |k| k.name == '73ce2cc1' }
        key_name = 'default'
        @rest_client.stub(:sshkeys) { key_data }
        @rest_client.stub(:find_key) { key_data.detect {|k| k.name == key_name } }

        subject.run_next_stage # key config is pretty much a noop here

        $terminal.write_line('yes')
        $terminal.write_line(key_name)

        # run the key check stage
        subject.run_next_stage

        output = $terminal.read
        output.should match("Key with the name #{key_name} already exists. Updating")
      #end

      #it "should check for client tools and find them" do
        subject.setup_mock_has_git(true)
        subject.run_next_stage
        output = $terminal.read
        output.should match(/Checking for git .*found/)
      #end

      #it "should show namespace" do
        subject.run_next_stage
        output = $terminal.read
        output.should match(/Checking your namespace/)
        output.should match(@namespace)
      #end

      #it "should list apps" do
        subject.run_next_stage
        output = $terminal.read
        output.should match("test1 http://test1-#{@namespace}.#{subject.openshift_server}/")
        output.should match("test2 http://test2-#{@namespace}.#{subject.openshift_server}/")
      #end

      #it "should show a thank you message" do
        subject.run_next_stage
        output = $terminal.read
        output.should match("Your client tools are now configured")
      end
    end

    context "Repeat run of rhc setup with everything set but platform set to Windows" do
      subject{ RerunWizardDriver.new }
      before(:all) do
        mock_config
        subject.windows = true
        subject.run_next_stage
      end

      it "should ask password input" do
        subject.stub_rhc_client_new
        # queue up input
        $terminal.write_line "#{subject.mock_user}"
        $terminal.write_line "password"

        subject.run_next_stage

        output = $terminal.read
        output.should match("Login to ")
        output.should match(/Password: [\*]{8}$/)
      #end

      #it "should write out a config" do
        File.exists?(subject.config_path).should be false
        subject.run_next_stage
        File.readable?(subject.config_path).should be true
        cp = RHC::Vendor::ParseConfig.new subject.config_path
        cp["default_rhlogin"].should == subject.mock_user
        cp["libra_server"].should == subject.openshift_server
      #end

      #it "should check for ssh keys and decline uploading them" do
        subject.setup_mock_ssh
        subject.run_next_stage
        RHC.stub(:get_ssh_keys) { {"keys" => [], "fingerprint" => nil} }
        $terminal.write_line('no')
        subject.run_next_stage
        output = $terminal.read
        output.should match("rhc sshkey")
      #end

      #it "should print out windows client tool info" do
        subject.run_next_stage
        output = $terminal.read
        output.should match("Git for Windows")
      #end

      #it "should ask for namespace and decline entering one" do
        $terminal.write_line("")
        subject.run_next_stage
        output = $terminal.read
        output.should match("rhc domain create")
      #end

      #it "should list apps without domain" do
        subject.setup_mock_domain_and_applications(nil, 'test1' => nil, 'test2' => nil)
        subject.run_next_stage
        output = $terminal.read
        output.should match("test1")
        output.should match("test2")
      end

    end

    context "Do a complete run through the wizard" do
      subject{ FirstRunWizardDriver.new }
      before(:all) do
        mock_config
      end

      it "should run" do
#        subject.openshift_server = nil
        subject.stub_rhc_client_new
        subject.setup_mock_ssh

        RHC.stub(:get_ssh_keys) { {"keys" => [], "fingerprint" => nil} }
        mock_carts = ['ruby', 'python', 'jbosseap']
        @rest_client.stub(:cartridges) { mock_carts }

        $terminal.write_line "#{subject.mock_user}"
        $terminal.write_line "password"
        $terminal.write_line('no')
        $terminal.write_line("")

        subject.run.should be_true
      end

      it "should fail" do
        subject.stub_rhc_client_new
        subject.stub(:login_stage) { nil }
        subject.run.should be_nil
      end
    end

    context "Check SSHWizard" do
      let(:wizard) { SSHWizardDriver.new }
      before(:each) { mock_config }

      it "should generate and upload keys since the user does not have them" do
        key_name = 'default'
        $terminal.write_line("yes\n#{key_name}\n")

        wizard.run.should be_true

        output = $terminal.read
        output.should match("Uploading key '#{key_name}'")
      end

      it "should pass through since the user has keys already" do
        wizard.stub(:ssh_key_uploaded?) { true }

        wizard.run.should be_true

        output = $terminal.read
        output.should == ""
      end
    end

    context "Check odds and ends" do
      before(:each) { mock_config }
      let(:wizard){ RerunWizardDriver.new }

      it "should cause ssh_key_upload? to catch NoMethodError and call the fallback to get the fingerprint" do
        Net::SSH::KeyFactory.stub(:load_public_key) { raise NoMethodError }
        @fallback_run = false
        wizard.stub(:ssh_keygen_fallback) { @fallback_run = true }
        key_data = wizard.get_mock_key_data
        @rest_client.stub(:sshkeys) { key_data }

        wizard.send(:ssh_key_uploaded?)

        @fallback_run.should be_true
      end

      it "should cause upload_ssh_key to catch NoMethodError and call the fallback to get the fingerprint" do
        wizard.ssh_keys = wizard.get_mock_key_data
        @fallback_run = false
        wizard.stub(:ssh_keygen_fallback) do
          @fallback_run = true
          [OpenStruct.new( :name => 'default', :fingerprint => 'AA:BB:CC:DD:EE:FF', :type => 'ssh-rsa' )]
        end
        $?.stub(:exitstatus) { 255 }
        Net::SSH::KeyFactory.stub(:load_public_key) { raise NoMethodError }

        wizard.send(:upload_ssh_key).should be_false

        output = $terminal.read
        output.should match("Your ssh public key at .* is invalid or unreadable\.")
        @fallback_run.should be_true
      end

      it "should cause upload_ssh_key to catch NotImplementedError and return false" do
        wizard.ssh_keys = wizard.get_mock_key_data
        Net::SSH::KeyFactory.stub(:load_public_key) { raise NotImplementedError }

        wizard.send(:upload_ssh_key).should be_false

        output = $terminal.read
        output.should match("Your ssh public key at .* is invalid or unreadable\.")
      end

      it "should match ssh key fallback fingerprint to net::ssh fingerprint" do
        # we need to write to a live file system so ssh-keygen can find it
        FakeFS.deactivate!
        Dir.mktmpdir do |dir|
          wizard.setup_mock_ssh_keys(dir)
          pub_ssh = File.join dir, "id_rsa.pub"
          fallback_fingerprint = wizard.send :ssh_keygen_fallback, pub_ssh
          internal_fingerprint, short_name = wizard.get_key_fingerprint pub_ssh

          fallback_fingerprint.should == internal_fingerprint
        end
        FakeFS.activate!
      end

      context "with the first run wizard" do
        let(:wizard){ FirstRunWizardDriver.new }

        it "prints the exception message when a domain error occurs" do
          msg = "Resource conflict"
          wizard.rest_client.stub(:add_domain) { raise RHC::Rest::ValidationException, msg }
          $terminal.write_line "testnamespace" # try to add a namespace
          $terminal.write_line '' # the above input will raise exception.
                                  # we now skip configuring namespace.
          wizard.send(:ask_for_namespace)
          output = $terminal.read
          output.should match msg
        end

        it "should update the key correctly" do
          key_name = 'default'
          key_data = wizard.get_mock_key_data
          wizard.ssh_keys = key_data
          wizard.stub(:get_preferred_key_name) { key_name }
          wizard.stub(:ssh_key_triple_for_default_key) { wizard.pub_key.chomp.split }
          wizard.stub(:fingerprint_for_default_key) { "" } # this value is irrelevant
          wizard.rest_client.stub(:find_key) { key_data.detect { |k| k.name == key_name } }

          wizard.send(:upload_ssh_key)
          output = $terminal.read
          output.should match 'Updating'
        end

        it 'should pick a usable SSH key name' do
          File.exists?('1').should be_false
          key_name = 'default'
          key_data = wizard.get_mock_key_data
          Socket.stub(:gethostname) { key_name }
          $terminal.write_line("\n") # to accept default key name
          wizard.ssh_keys = key_data
          wizard.stub(:ssh_key_triple_for_default_key) { wizard.pub_key.chomp.split }
          wizard.stub(:fingerprint_for_default_key) { "" } # this value is irrelevant
          wizard.rest_client.stub(:add_key) { true }

          wizard.send(:upload_ssh_key)
          output = $terminal.read
          # since the clashing key name is short, we expect to present
          # a key name with "1" attached to it.
          output.should match "|" + key_name + "1" + "|"
          File.exists?('1').should be_false
        end
      end
    end
  end

  module WizardDriver
    attr_accessor :mock_user, :rest_client
    def initialize(*args)
      if args.empty?
        args = [RHC::Config.new, Commander::Command::Options.new]
        args[1].default(args[0].to_options)
      end
      super *args
      raise "No options" if options.nil?
      @mock_user = 'mock_user@foo.bar'
      @current_wizard_stage = nil
      @platform_windows = false
      #self.stub(:openshift_server).and_return('fake.foo')
    end

    def run_next_stage
      if @current_wizard_stage.nil?
        @current_wizard_stage = 0
      else
        return false if @current_wizard_stage >= stages.length + 1
        @current_wizard_stage += 1
      end

      self.send stages[@current_wizard_stage]
    end

    # Set up @rest_client so that we can stub subsequent REST calls
    def stub_rhc_client_new
      @rest_client = RestSpecHelper::MockRestClient.new
    end

    def setup_mock_config(rhlogin=@mock_user)
      FileUtils.mkdir_p File.dirname(RHC::Config.local_config_path)
      File.open(RHC::Config.local_config_path, "w") do |file|
        file.puts <<EOF
# Default user login
default_rhlogin='#{rhlogin}'

# Server API
libra_server = '#{openshift_server}'
EOF
      end

      # reload config
      @config = RHC::Config.initialize
      RHC::Config.ssh_dir.should =~ /mock_user/
      @config.ssh_dir.should =~ /mock_user/
    end

    def setup_mock_ssh(add_ssh_key=false)
      FileUtils.mkdir_p ssh_dir
      if add_ssh_key
        setup_mock_ssh_keys
      end
    end

    def setup_mock_has_git(bool)
      self.stub(:"has_git?") { bool }
    end

    def setup_mock_domain_and_applications(domain, apps = {})
      stub_rhc_client_new
      apps_ary = []
      apps.each do |app, url|
        apps_ary.push OpenStruct.new(
          :name => app,
          :app_url => url == :default ? "http://#{app}-#{domain}.#{openshift_server}/" : url,
          :u => true
        )
      end

      @rest_client.stub(:domains) {
        [OpenStruct.new(:id => domain, :applications => apps_ary)]
      }
    end

    def ssh_dir
      @config.ssh_dir
    end

    def windows=(bool)
      @platform_windows = bool
    end

    def windows?
      @platform_windows
    end

    def get_key_fingerprint(path=RHC::Config.ssh_pub_key_file_path)
      # returns the fingerprint and the short name used as the default
      # key name
      fingerprint = Net::SSH::KeyFactory.load_public_key(path).fingerprint
      short_name = fingerprint[0, 12].gsub(/[^0-9a-zA-Z]/,'')
      return fingerprint, short_name
    end

    def ssh_keys=(data)
      @ssh_keys = data
    end

    class Sshkey < OpenStruct
      def update(type, content)
        self.type = type
        self.content = content
      end
      def type
        @table[:type]
      end
      def type=(type)
        @table[:type] = type
      end
    end

    def get_mock_key_data
      [
        Sshkey.new(:name => 'default',  :type => 'ssh-rsa', :fingerprint => "0f:97:4b:82:87:bb:c6:dc:40:a3:c1:bc:bb:55:1e:fa"),
        Sshkey.new(:name => 'cb490595', :type => 'ssh-rsa', :fingerprint => "cb:49:05:95:b4:42:1c:95:74:f7:2d:41:0d:f0:37:3b"),
        Sshkey.new(:name => '96d90241', :type => 'ssh-rsa', :fingerprint => "96:d9:02:41:e1:cb:0d:ce:e5:3b:fc:da:13:65:3e:32"),
        Sshkey.new(:name => '73ce2cc1', :type => 'ssh-rsa', :fingerprint => "73:ce:2c:c1:01:ea:79:cc:f6:be:86:45:67:96:7f:e3")
      ]
    end

    def priv_key
      <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIICWwIBAAKBgQDIXpBBs7g93z/5JqW5IJNJR8bG6DWhpL2vR2ROEfzGqDHLZ+Xb
saS/Ogc3nZNSav3juHWdiBFIc0unPpLdwmXtcL3tjN52CJqPgU/W0q061fL/tk77
fFqW2upluo0ZRZQdPc3vTI3tWWZcpyE2LPHHUOI3KN+lRqxgw0Y6z/3SfwIDAQAB
AoGAbMC+xZp5TsPEokOywWeH6cdWgZF5wpF7Dw7Nx34F2AFkfYWYAgVKaSxizHHv
i1VdFmOBGw7Gaq+BiXXyGwEvdpmgDoZDwvJrShZef5LwYnJ/NCqjZ8Xbb9z4VxCL
pkqMFFpEeNQcIDLZRF8Z1prRQnOL+Z498P6d3G/UWkR5NXkCQQDsGlpJzJwAPpwr
YZ98LgKT0n2WHeCrMQ9ZyJQl3Dz40qasQmIotB+mdIh87EFex7vvyiuzRC5rfcoX
CBHEkQpVAkEA2UFNBKgI1v5+16K0/CXPakQ25AlGODDv2VXlHwRPOayUG/Tn2joj
fj0T4/pu9AGhz0oVXFlz7iO8PEwFU+plgwJAKD2tmdp31ErXj0VKS34EDnHX2dgp
zMPF3AWlynYpJjexFLcTx+A7bMF76d7SnXbpf0sz+4/pYYTFBvvnG1ulKQJACJsR
lfGiCAIkvB3x1VsaEDeLhRTo9yjZF17TqJrfGIXBiCn3VSmgZku9EfbFllzKMA/b
MMFKWlCIEEtimqRaSQJAPVA1E7AiEvfUv0kRT73tDf4p/BRJ7p2YwjxrGpDBQhG1
YI+4NOhWtAG3Uips++8RhvmLjv8y+TNKU31J1EJmYA==
-----END RSA PRIVATE KEY-----
EOF
    end

    def pub_key
      <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDIXpBBs7g93z/5JqW5IJNJR8bG6DWhpL2vR2ROEfzGqDHLZ+XbsaS/Ogc3nZNSav3juHWdiBFIc0unPpLdwmXtcL3tjN52CJqPgU/W0q061fL/tk77fFqW2upluo0ZRZQdPc3vTI3tWWZcpyE2LPHHUOI3KN+lRqxgw0Y6z/3Sfw== OpenShift-Key
EOF
    end

    def setup_mock_ssh_keys(dir=ssh_dir)
      private_key_file = File.join(dir, "id_rsa")
      public_key_file = File.join(dir, "id_rsa.pub")
      File.open(private_key_file, 'w') { |f| f.write priv_key }

      File.open(public_key_file, 'w') { |f| f.write pub_key }
    end

    def config_path
      config.path
    end
    def openshift_server
      super
    end
#    def config(local_conf_path=nil)
#      @config.set_local_config(local_conf_path, false) if local_conf_path
#      @config
#    end
  end

  class FirstRunWizardDriver < RHC::Wizard
    include WizardDriver
  end

  class RerunWizardDriver < RHC::RerunWizard
    include WizardDriver
  end

  class SSHWizardDriver < RHC::SSHWizard
    include WizardDriver

    def initialize
      super RestSpecHelper::MockRestClient.new, RHC::Config.new, Commander::Command::Options.new
    end
  end
end
