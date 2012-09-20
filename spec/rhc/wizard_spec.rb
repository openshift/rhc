require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/wizard'
require 'rhc/vendor/parseconfig'
require 'rhc/config'
require 'ostruct'

describe RHC::Wizard do
  before(:all) do
    mock_terminal
    FakeFS.activate!
  end

  after(:all) do
    FakeFS::FileSystem.clear
    FakeFS.deactivate!
  end

  context "First run of rhc" do
    before(:all) do
      @wizard = FirstRunWizardDriver.new
    end

    it "should print out first run greeting" do
      @wizard.run_next_stage
      greeting = $terminal.read
      greeting.count("\n").should >= 7
      greeting.should match(Regexp.escape("It looks like you have not configured or used OpenShift client tools on this computer."))
      greeting.should match(Regexp.escape("\n#{@wizard.config_path}\n"))
    end

    it "should ask for login and hide password input" do
      @wizard.stub_rhc_client_new
      # queue up input
      $terminal.write_line "#{@wizard.mock_user}"
      $terminal.write_line "password"

      @wizard.stub_user_info

      @wizard.run_next_stage

      output = $terminal.read
      output.should match("OpenShift login")
      output.should =~ /(#{Regexp.escape("Password: ********\n")})$/
    end

    it "should write out a config" do
      File.exists?(@wizard.config_path).should be false
      @wizard.run_next_stage
      File.readable?(@wizard.config_path).should be true
      cp = RHC::Vendor::ParseConfig.new @wizard.config_path
      cp["default_rhlogin"].should == @wizard.mock_user
      cp["libra_server"].should == @wizard.libra_server
    end

    it "should write out generated ssh keys" do
      @wizard.setup_mock_ssh
      private_key_file = File.join(@wizard.ssh_dir, "id_rsa")
      public_key_file = File.join(@wizard.ssh_dir, "id_rsa.pub")
      File.exists?(private_key_file).should be false
      File.exists?(public_key_file).should be false
      @wizard.run_next_stage
      File.exists?(private_key_file).should be true
      File.exists?(public_key_file).should be true
    end

    it "should ask to upload ssh keys" do
      @rest_client.stub(:get_ssh_keys) { @wizard.get_mock_key_data }
      $terminal.write_line('yes')
      @wizard.stub_rhc_client_new
      @wizard.ssh_keys = []
      @wizard.run_next_stage
    end

    it "should check for client tools" do
      @wizard.setup_mock_has_git(true)
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Checking for git \.\.\. found")
    end

    it "should ask for a namespace" do
      @wizard.stub_user_info
      $terminal.write_line("thisnamespaceistoobigandhastoomanycharacterstobevalid")

      $terminal.write_line("invalidnamespace")
      $terminal.write_line("testnamespace")
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Checking for your namespace \.\.\. not found")
    end

    it "should show app creation commands" do
      mock_carts = ['ruby', 'python', 'jbosseap']
      RHC.stub(:get_cartridges_list) { mock_carts }
      @wizard.stub_user_info
      @wizard.run_next_stage
      output = $terminal.read
      mock_carts.each do |cart|
        output.should match("\\* #{cart} - rhc app create -t #{cart} -a <app name>")
      end
    end

    it "should show a thank you message" do
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("The OpenShift client tools have been configured on your computer")
    end
  end

  context "Repeat run of rhc setup without anything set" do
    before(:all) do
      @wizard = RerunWizardDriver.new
    end

    it "should print out repeat run greeting" do
      @wizard.run_next_stage
      greeting = $terminal.read
      greeting.count("\n").should == 7
      greeting.should match(Regexp.escape("Starting Interactive Setup for OpenShift's command line interface"))
      greeting.should match(Regexp.escape("#{@wizard.config_path}\n"))
    end

    it "should ask for login and hide password input" do
      @wizard.stub_rhc_client_new
      $terminal.write_line "#{@wizard.mock_user}"
      $terminal.write_line "password"

      @wizard.stub_user_info

      @wizard.run_next_stage

      output = $terminal.read
      output.should match("OpenShift login")
      output.should =~ /(#{Regexp.escape("Password: ********\n")})$/
    end

    it "should write out a config" do
      File.exists?(@wizard.config_path).should be false
      @wizard.run_next_stage
      File.readable?(@wizard.config_path).should be true
      cp = RHC::Vendor::ParseConfig.new @wizard.config_path
      cp["default_rhlogin"].should == @wizard.mock_user
      cp["libra_server"].should == @wizard.libra_server
    end

    it "should write out generated ssh keys" do
      @wizard.setup_mock_ssh
      private_key_file = File.join(@wizard.ssh_dir, "id_rsa")
      public_key_file = File.join(@wizard.ssh_dir, "id_rsa.pub")
      File.exists?(private_key_file).should be false
      File.exists?(public_key_file).should be false
      @wizard.run_next_stage
      File.exists?(private_key_file).should be true
      File.exists?(public_key_file).should be true
    end

    it "should upload ssh key as default" do
      RHC::Rest::Client.stub(:sshkeys) { {} }
      WizardDriver::MockRestApi.stub(:sshkeys) {[]}
      WizardDriver::MockRestApi.stub(:add_key) {{}}
      $terminal.write_line('yes')
      @wizard.run_next_stage
    end

    it "should check for client tools and print they need to be installed" do
      @wizard.setup_mock_has_git(false)
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Checking for git \.\.\. needs to be installed")
      output.should match("Automated installation of client tools is not supported for your platform")
    end

    it "should ask for a namespace" do
      @wizard.stub_user_info
      $terminal.write_line("testnamespace")
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Checking for your namespace \.\.\. not found")
    end

    it "should show app creation commands" do
      mock_carts = ['ruby', 'python', 'jbosseap']
      RHC.stub(:get_cartridges_list) { mock_carts }
      @wizard.stub_user_info
      @wizard.run_next_stage
      output = $terminal.read
      mock_carts.each do |cart|
        output.should match("\\* #{cart} - rhc app create -t #{cart} -a <app name>")
      end
    end

    it "should show a thank you message" do
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Thank you")
    end
  end

  context "Repeat run of rhc setup with config set" do
    before(:all) do
      RHC::Config.set_defaults
      @wizard = RerunWizardDriver.new
      @wizard.setup_mock_config
      @wizard.run_next_stage # we can skip testing the greeting
    end

    it "should ask for password input with default login" do
      @wizard.stub_rhc_client_new
      @wizard.stub_user_info

      $terminal.write_line("") # hit enter for default
      $terminal.write_line "password"

      @wizard.run_next_stage

      output = $terminal.read
      output.should match("|#{@wizard.mock_user}|")
    end

    it "should write out a config" do
      File.exists?(@wizard.config_path).should be true
      @wizard.run_next_stage
      File.readable?(@wizard.config_path).should be true
      cp = RHC::Vendor::ParseConfig.new @wizard.config_path
      cp["default_rhlogin"].should == @wizard.mock_user
      cp["libra_server"].should == @wizard.libra_server
    end

    it "should write out generated ssh keys" do
      @wizard.setup_mock_ssh
      private_key_file = File.join(@wizard.ssh_dir, "id_rsa")
      public_key_file = File.join(@wizard.ssh_dir, "id_rsa.pub")
      File.exists?(private_key_file).should be false
      File.exists?(public_key_file).should be false
      @wizard.run_next_stage
      File.exists?(private_key_file).should be true
      File.exists?(public_key_file).should be true
    end

    it "should find out that you have not uploaded the default key and ask to name the key" do
      key_data = @wizard.get_mock_key_data
      @wizard.ssh_keys = key_data

      fingerprint, short_name = @wizard.get_key_fingerprint
      $terminal.write_line('yes')
      $terminal.write_line("") # use default name
      @wizard.run_next_stage
      output = $terminal.read
      key_data.each do |key|
        output.should match("#{key.name} - #{key.fingerprint}")
      end
      output.should match("|#{short_name}|")
    end

    it "should check for client tools via package kit and find them" do
      @wizard.setup_mock_package_kit(true)

      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Checking for git \.\.\. found")
    end

    it "should ask for a namespace" do
      @wizard.stub_user_info
      $terminal.write_line("testnamespace")
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Checking for your namespace \.\.\. not found")
    end

    it "should show app creation commands" do
      mock_carts = ['ruby', 'python', 'jbosseap']
      RHC.stub(:get_cartridges_list) { mock_carts }
      @wizard.stub_user_info
      @wizard.run_next_stage
      output = $terminal.read
      mock_carts.each do |cart|
        output.should match("\\* #{cart} - rhc app create -t #{cart} -a <app name>")
      end
    end

    it "should show a thank you message" do
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Thank you")
    end
  end

  context "Repeat run of rhc setup with config and ssh keys set" do

    before(:all) do
      @wizard = RerunWizardDriver.new
      @wizard.setup_mock_config
      @wizard.setup_mock_ssh(true)
      @wizard.run_next_stage # we can skip testing the greeting
    end

    it "should ask for password input with default login" do
      @wizard.stub_rhc_client_new
      @wizard.stub_user_info

      $terminal.write_line("") # hit enter for default
      $terminal.write_line "password"

      @wizard.run_next_stage

      output = $terminal.read
      output.should match("|#{@wizard.mock_user}|")
    end

    it "should write out a config" do
      File.exists?(@wizard.config_path).should be true
      @wizard.run_next_stage
      File.readable?(@wizard.config_path).should be true
      cp = RHC::Vendor::ParseConfig.new @wizard.config_path
      cp["default_rhlogin"].should == @wizard.mock_user
      cp["libra_server"].should == @wizard.libra_server
    end

    it "should check for ssh keys and find a match" do
      @wizard.stub(:ssh_key_uploaded?) { true } # an SSH key already exists
      @wizard.run_next_stage # key config is pretty much a noop here

      # run the key check stage
      @wizard.run_next_stage

      output = $terminal.read
      output.should_not match("ssh key must be uploaded")
    end

    it "should check for client tools and find them" do
      @wizard.setup_mock_has_git(true)
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Checking for git \.\.\. found")
    end

    it "should ask for a namespace" do
      @wizard.stub_user_info
      $terminal.write_line("testnamespace")
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Checking for your namespace \.\.\. not found")
    end

    it "should show app creation commands" do
      mock_carts = ['ruby', 'python', 'jbosseap']
      RHC.stub(:get_cartridges_list) { mock_carts }
      @wizard.stub_user_info
      @wizard.run_next_stage
      output = $terminal.read
      mock_carts.each do |cart|
        output.should match("\\* #{cart} - rhc app create -t #{cart} -a <app name>")
      end
    end

    it "should show a thank you message" do
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Thank you")
    end
  end

  context "Repeat run of rhc setup with everything set" do
    before(:all) do
      @wizard = RerunWizardDriver.new
      @wizard.setup_mock_config("old_mock_user@bar.baz")
      @wizard.setup_mock_ssh(true)
      @wizard.run_next_stage # we can skip testing the greeting
    end

    it "should ask password input with default login(use a different one)" do
      @wizard.stub_rhc_client_new
      @wizard.stub_user_info
      $terminal.write_line(@wizard.mock_user)
      $terminal.write_line "password"

      @wizard.run_next_stage

      output = $terminal.read
      output.should match("|old_mock_user@bar.baz|")
    end

    it "should write out a config" do
      File.exists?(@wizard.config_path).should be true
      @wizard.run_next_stage
      File.readable?(@wizard.config_path).should be true
      cp = RHC::Vendor::ParseConfig.new @wizard.config_path
      cp["default_rhlogin"].should == @wizard.mock_user
      cp["libra_server"].should == @wizard.libra_server
    end

    it "should check for ssh keys, not find it on the server and update existing key" do
      key_data = @wizard.get_mock_key_data
      key_data.delete_if { |k| k.name == '73ce2cc1' }
      @rest_client.stub(:sshkeys) { key_data }

      @wizard.run_next_stage # key config is pretty much a noop here

      $terminal.write_line('yes')
      $terminal.write_line('default')

      # run the key check stage
      @wizard.run_next_stage

      output = $terminal.read
      output.should match("Uploading key 'default'")
    end

    it "should check for client tools and find them" do
      @wizard.setup_mock_has_git(true)
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Checking for git \.\.\. found")
    end

    it "should show namespace" do
      @wizard.stub_user_info([{"namespace" => "setnamespace"}])
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Checking for your namespace ... found namespace:")
      output.should match("setnamespace")
    end

    it "should list apps" do
      @wizard.stub_user_info([{"namespace" => "setnamespace"}],
                             {"test1" => {},
                              "test2" => {}
                             }
                            )
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("test1 - http://test1-setnamespace.#{@wizard.libra_server}/")
      output.should match("test2 - http://test2-setnamespace.#{@wizard.libra_server}/")
    end

    it "should show a thank you message" do
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Thank you")
    end
  end

  context "Repeat run of rhc setup with everything set but platform set to Windows" do
    before(:all) do
      @wizard = RerunWizardDriver.new
      @wizard.windows = true
      @wizard.run_next_stage
    end

    it "should ask password input" do
      @wizard.stub_rhc_client_new
      # queue up input
      $terminal.write_line "#{@wizard.mock_user}"
      $terminal.write_line "password"

      @wizard.stub_user_info

      @wizard.run_next_stage

      output = $terminal.read
      output.should match("OpenShift login")
      output.should =~ /(#{Regexp.escape("Password: ********\n")})$/
    end

    it "should write out a config" do
      File.exists?(@wizard.config_path).should be false
      @wizard.run_next_stage
      File.readable?(@wizard.config_path).should be true
      cp = RHC::Vendor::ParseConfig.new @wizard.config_path
      cp["default_rhlogin"].should == @wizard.mock_user
      cp["libra_server"].should == @wizard.libra_server
    end

    it "should check for ssh keys and decline uploading them" do
      @wizard.setup_mock_ssh
      @wizard.run_next_stage
      RHC.stub(:get_ssh_keys) { {"keys" => [], "fingerprint" => nil} }
      $terminal.write_line('no')
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("rhc sshkey")
    end

    it "should print out windows client tool info" do
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("Git for Windows")
    end

    it "should ask for namespace and decline entering one" do
      @wizard.stub_user_info
      $terminal.write_line("")
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("rhc domain create")
    end

    it "should list apps without domain" do
      @wizard.stub_user_info([],
                             {"test1" => {},
                              "test2" => {}
                             }
                            )
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("test1 - no public url")
      output.should match("test2 - no public url")
    end

  end

  context "Do a complete run through the wizard" do
    before(:all) do
      @wizard = FirstRunWizardDriver.new
    end

    it "should run" do
      @wizard.libra_server = nil
      @wizard.stub_rhc_client_new
      @wizard.stub_user_info
      @wizard.setup_mock_ssh

      RHC.stub(:get_ssh_keys) { {"keys" => [], "fingerprint" => nil} }
      mock_carts = ['ruby', 'python', 'jbosseap']
      RHC.stub(:get_cartridges_list) { mock_carts }

      $terminal.write_line "#{@wizard.mock_user}"
      $terminal.write_line "password"
      $terminal.write_line('no')
      $terminal.write_line("")

      @wizard.run().should be_true
    end

    it "should fail" do
      @wizard.stub_rhc_client_new
      @wizard.stub_user_info
      @wizard.stub(:login_stage) { nil }
      @wizard.run().should be_nil
    end

    it "should cover package kit install steps" do
      @wizard.libra_server = nil
      @wizard.stub_rhc_client_new
      @wizard.stub_user_info
      @wizard.setup_mock_ssh
      @wizard.setup_mock_package_kit(false)

      @rest_client.stub(:get_ssh_keys) { [] }
      mock_carts = ['ruby', 'python', 'jbosseap']
      RHC.stub(:get_cartridges_list) { mock_carts }
      # we need to do this because get_character does not get caught
      # by our mock terminal
      @wizard.stub(:get_character) {ask ""}

      $terminal.write_line ""
      $terminal.write_line "password"
      $terminal.write_line("no")
      $terminal.write_line("yes")
      $terminal.write_line("")
      $terminal.write_line("")

      @wizard.run().should be_true

      output = $terminal.read
      output.should match("You may safely continue while the installer is running")
    end
  end

  context "Check SSHWizard" do
    it "should generate and upload keys since the user does not have them" do
      wizard = SSHWizardDriver.new
      wizard.stub_rhc_client_new
      @rest_client.stub(:sshkeys) { [] }
      @rest_client.stub(:add_key) { true } # assume key is added succesfully
      wizard.stub_user_info
      $terminal.write_line("yes")

      wizard.run().should be_true

      output = $terminal.read
      output.should match("Uploading key 'default'")
    end

    it "should pass through since the user has keys already" do
      wizard = SSHWizardDriver.new
      wizard.stub_rhc_client_new
      wizard.stub_user_info
      wizard.setup_mock_ssh(true)
      key_data = wizard.get_mock_key_data
      wizard.stub(:ssh_key_uploaded?) { true } # an SSH key already exists

      wizard.run().should be_true

      output = $terminal.read
      output.should == ""
    end
  end

  context "Check odds and ends" do
    it "should call dbus_send_session_method and get multiple return values" do
      wizard = FirstRunWizardDriver.new
      wizard.stub(:dbus_send_exec) do |cmd|
        "\\nboolean true\\nboolean false\\nstring hello\\nother world\\n"
      end
      results = wizard.send(:dbus_send_session_method, "test", "foo.bar", "bar/baz", "alpha.Beta", "")
      results.should == [true, false, "hello", "world"]
    end

    it "should call dbus_send_session_method and get one return value" do
      wizard = FirstRunWizardDriver.new
      wizard.stub(:dbus_send_exec) do |cmd|
        "\\nstring hello world\\n"
      end
      results = wizard.send(:dbus_send_session_method, "test", "foo.bar", "bar/baz", "alpha.Beta", "")
      results.should == "hello world"
    end

    it "should cause has_git? to catch an exception and return false" do
      wizard = FirstRunWizardDriver.new
      wizard.stub(:git_version_exec){ raise "Fake Exception" }
      wizard.send(:has_git?).should be_false
    end

    it "should cause package_kit_install to catch exception and call generic_unix_install_check" do
      wizard = RerunWizardDriver.new
      wizard.setup_mock_package_kit(false)
      wizard.stub(:dbus_send_exec) do |cmd|
        "Error: mock error" if cmd.start_with?("dbus-send")
      end
      wizard.send(:package_kit_install)

      output = $terminal.read
      output.should match("Checking for git ... needs to be installed")
      output.should match("Automated installation of client tools is not supported")
    end

    it "should cause ssh_key_upload? to catch NoMethodError and call the fallback to get the fingerprint" do
      wizard = RerunWizardDriver.new
      Net::SSH::KeyFactory.stub(:load_public_key) { raise NoMethodError }
      @fallback_run = false
      wizard.stub(:ssh_keygen_fallback) { @fallback_run = true }
      key_data = wizard.get_mock_key_data
      @rest_client.stub(:sshkeys) { key_data }

      wizard.send(:ssh_key_uploaded?)

      @fallback_run.should be_true
    end

    it "should cause upload_ssh_key to catch NoMethodError and call the fallback to get the fingerprint" do
      wizard = RerunWizardDriver.new
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
      wizard = RerunWizardDriver.new
      wizard.ssh_keys = wizard.get_mock_key_data
      Net::SSH::KeyFactory.stub(:load_public_key) { raise NotImplementedError }

      wizard.send(:upload_ssh_key).should be_false

      output = $terminal.read
      output.should match("Your ssh public key at .* is invalid or unreadable\.")
    end

    it "should match ssh key fallback fingerprint to net::ssh fingerprint" do
      # we need to write to a live file system so ssh-keygen can find it
      FakeFS.deactivate!
      wizard = RerunWizardDriver.new
      Dir.mktmpdir do |dir|
        wizard.setup_mock_ssh_keys(dir)
        pub_ssh = File.join dir, "id_rsa.pub"
        fallback_fingerprint = wizard.send :ssh_keygen_fallback, pub_ssh
        internal_fingerprint, short_name = wizard.get_key_fingerprint pub_ssh

        fallback_fingerprint.should == internal_fingerprint
      end
      FakeFS.activate!
    end
  end

  module WizardDriver
    class MockDomain
      attr_accessor :id

      def initialize(id)
        @id = id
      end
    end
    class MockRestApi
      attr_accessor :sshkeys

      def initialize(end_point, name, password)
        @end_point = end_point
        @name = name
        @password = password
        @domain_name = 'testnamespace'
        @sshkeys = {}
      end

      def add_domain(domain_name)
        raise RHC::Rest::ValidationException.new("Error: domain name should be '#{@domain_name}' but got '#{domain_name}'") if domain_name != @domain_name

        MockDomain.new(domain_name)
      end

      def add_key(name, content, type)
        @sshkeys[name.to_sym] = ::RestSpecHelper::MockRestKey.new(name, type, content)
      end
    end

    attr_accessor :mock_user, :libra_server, :config_path, :ssh_dir
    def initialize(*args)
      RHC::Config.home_dir = '/home/mock_user'
      super *args
      @ssh_dir = "#{RHC::Config.home_dir}/.ssh/"
      @libra_server = 'mock.openshift.redhat.com'
      @mock_user = 'mock_user@foo.bar'
      @current_wizard_stage = nil
      @platform_windows = false
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
      RHC::Rest::Client.stub(:new) do |end_point, name, password|
        @rest_client = MockRestApi.new(end_point, name, password)
      end
    end

    def stub_user_info(domains=[], app_info=[], key_type="", key="", keys={})
      RHC.stub(:get_user_info) do
        {"ssh_key" => key,
         "ssh_key_type" => key_type,
         "keys" => keys,
         "app_info" => app_info,
         "user_info" => {"domains" => domains,
                         "rhc_domain" => @libra_server},
         "domains" => domains,
         "rhlogin" => @mock_user}
      end
    end

    def setup_mock_config(rhlogin=@mock_user)
      FileUtils.mkdir_p File.dirname(@config_path)
      File.open(@config_path, "w") do |file|
        file.puts <<EOF
# Default user login
default_rhlogin='#{rhlogin}'

# Server API
libra_server = '#{@libra_server}'
EOF
      end

      # reload config
      @config.home_dir = '/home/mock_user'
    end

    def setup_mock_ssh(add_ssh_key=false)
      FileUtils.mkdir_p @ssh_dir
      if add_ssh_key
        setup_mock_ssh_keys
      end
    end

    def setup_mock_package_kit(bool)
      ENV['PATH'] = '/usr/bin' unless ENV['PATH']
      ENV['DBUS_SESSION_BUS_ADDRESS'] = "present" unless ENV['DBUS_SESSION_BUS_ADDRESS']
      unless File.exists?('/usr/bin/dbus-send')
        FileUtils.mkdir_p '/usr/bin/'
        File.open('/usr/bin/dbus-send', 'w') { |f| f.write('dummy') }
      end

      setup_mock_has_git(false)

      self.stub(:dbus_send_session_method) do
        bool
      end
    end

    def setup_mock_has_git(bool)
      self.stub(:"has_git?") { bool }
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

    class Sshkey < OpenStruct; end

    def get_mock_key_data
      key_data = [
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

    def setup_mock_ssh_keys(dir=@ssh_dir)
      private_key_file = File.join(dir, "id_rsa")
      public_key_file = File.join(dir, "id_rsa.pub")
      File.open(private_key_file, 'w') { |f| f.write priv_key }

      File.open(public_key_file, 'w') { |f| f.write pub_key }
    end

    def config(local_conf_path)
      conf = RHC::Config
      conf.set_local_config(local_conf_path, false)
      conf
    end
  end

  class FirstRunWizardDriver < RHC::Wizard
    include WizardDriver

    def initialize
      super config('/home/mock_user/.openshift/express.conf')
    end
  end

  class RerunWizardDriver < RHC::RerunWizard
    include WizardDriver

    def initialize
      super config('/home/mock_user/.openshift/express.conf')
    end
  end

  class SSHWizardDriver < RHC::SSHWizard
    include WizardDriver

    def initialize
      super 'mock_user@foo.bar', 'password'
    end
  end
end
