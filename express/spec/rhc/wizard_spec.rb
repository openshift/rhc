require 'spec_helper'
require 'fakefs/safe'
require 'rhc/wizard'
require 'rhc/vendor/parseconfig'
require 'rhc/config'

# chmod isn't implemented in the released fakefs gem
# but is in git.  Once the git version is released we
# should remove this and actively check permissions
class FakeFS::File
  def self.chmod(*args)
    # noop
  end
end

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
      greeting.count("\n").should == 8
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
      RHC.stub(:get_ssh_keys) { {"keys" => [], "fingerprint" => nil} }
      @wizard.set_expected_key_name_and_action('default', 'add')
      $terminal.write_line('yes')
      @wizard.run_next_stage
    end

    it "should check for client tools" do
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
      output.should match ("The OpenShift client tools have been configured on your computer")
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
      RHC.stub(:get_ssh_keys) { {"keys" => [], "fingerprint" => nil} }
      @wizard.set_expected_key_name_and_action('default', 'add')
      $terminal.write_line('yes')
      @wizard.run_next_stage
    end

    it "should check for client tools and print they need to be installed" do
      @wizard.has_git(false)
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
      output.should match ("Thank you")
    end
  end

  context "Repeat run of rhc setup with config set" do
    before(:all) do
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

    it "should find out that you have not uploaded the keys and ask to name the key" do
      key_data = @wizard.get_mock_key_data
      RHC.stub(:get_ssh_keys) do
        key_data
      end

      fingerprint, short_name = @wizard.get_key_fingerprint
      @wizard.set_expected_key_name_and_action(short_name, 'add')
      $terminal.write_line('yes')
      $terminal.write_line("") # use default name
      @wizard.run_next_stage
      output = $terminal.read
      output.should match("default - #{key_data['fingerprint']}")
      key_data['keys'].each do |key, value|
        output.should match("#{key} - #{value['fingerprint']}")
      end
      output.should match("|#{short_name}|")
    end

    it "should check for client tools and find them" do
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
      output.should match ("Thank you")
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
      key_data = @wizard.get_mock_key_data
      RHC.stub(:get_ssh_keys) do
        key_data
      end
      @wizard.run_next_stage # key config is pretty much a noop here

      # run the key check stage
      @wizard.run_next_stage

      output = $terminal.read
      output.should_not match("ssh key must be uploaded")
    end

    it "should check for client tools and find them" do
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
      output.should match ("Thank you")
    end
  end

  context "Repeat run of rhc setup with everything set" do
    before(:all) do
      @wizard = RerunWizardDriver.new
      @wizard.setup_mock_config("old_mock_user@bar.baz")
      @wizard.setup_mock_ssh(true)
      @wizard.run_next_stage # we can skip testing the greeting
    end

    it "should ask password input with default login (use a different one)" do
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

    it "should check for ssh keys and find they are uploaded" do
      key_data = @wizard.get_mock_key_data
      RHC.stub(:get_ssh_keys) do
        key_data
      end

      @wizard.run_next_stage # key config is pretty much a noop here

      # run the key check stage
      @wizard.run_next_stage

      output = $terminal.read
      output.should_not match("ssh key must be uploaded")
    end

    it "should check for client tools and find them" do
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
      output.should match ("Thank you")
    end
  end

  context "Repeat run of rhc setup with everything set but platform set to Windows" do

    it "should print out repeat run greeting" do

    end

    it "should ask password input (not login)" do

    end

    it "should check for ssh keys and find they are uploaded" do

    end

    it "should print out windows client tool info" do

    end

    it "should show namespace" do

    end

    it "should list apps" do

    end

    it "should show a thank you message" do

    end

  end

  context "Do a complete run through the wizard" do
    before(:all) do
      @wizard = FirstRunWizardDriver.new
    end

    it "should run" do
      @wizard.stub_rhc_client_new
      @wizard.stub_user_info
      @wizard.setup_mock_ssh
      @wizard.set_expected_key_name_and_action('default', 'add')

      RHC.stub(:get_ssh_keys) { {"keys" => [], "fingerprint" => nil} }
      mock_carts = ['ruby', 'python', 'jbosseap']
      RHC.stub(:get_cartridges_list) { mock_carts }

      $terminal.write_line "#{@wizard.mock_user}"
      $terminal.write_line "password"
      $terminal.write_line('yes')
      $terminal.write_line("testnamespace")

      @wizard.run().should be_true
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
      def initialize(end_point, name, password)
        @end_point = end_point
        @name = name
        @password = password
        @domain_name = 'testnamespace'
      end

      def add_domain(domain_name)
        raise "Error: domain name should be '#{@domain_name}' but got '#{domain_name}'" if domain_name != @domain_name

        MockDomain.new(domain_name)
      end
    end

    attr_accessor :mock_user, :libra_server, :config_path, :ssh_dir
    def initialize
      RHC::Config.home_dir = '/home/mock_user'
      super '/home/mock_user/.openshift/openshift.conf'
      @ssh_dir = "#{RHC::Config.home_dir}/.ssh/"
      @libra_server = 'mock.openshift.redhat.com'
      @mock_user = 'mock_user@foo.bar'
      @mock_git_installed = true
      @mock_package_kit_installed = false
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

    def stub_rhc_client_new
      Rhc::Rest::Client.stub(:new) do |end_point, name, password|
        MockRestApi.new(end_point, name, password)
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
    end

    def setup_mock_ssh(add_ssh_key=false)
      FileUtils.mkdir_p @ssh_dir
      if add_ssh_key
        setup_mock_ssh_keys
      end
    end

    def has_git(bool)
      @mock_git_installed = bool
    end

    def has_git?
      @mock_git_installed
    end

    def has_dbus_send?
      @mock_package_kit_installed
    end

    def windows?
      @platform_windows
    end

    def set_expected_key_name_and_action(key_name, action)
      @expected_key_name = key_name
      @expected_key_action = action
    end

    def add_or_update_key(action, key_name, pub_ssh_path, username, password)
      raise "Error: Expected '#{@expected_key_action}' ssh key action but got '#{action}'" if @expected_key_action and action != @expected_key_action
      raise "Error: Expected '#{@expected_key_name}' ssh key name but got '#{key_name}'" if @expected_key_name and key_name != @expected_key_name
      true
    end

    def get_key_fingerprint
      # returns the fingerprint and the short name used as the default
      # key name
      fingerprint = Net::SSH::KeyFactory.load_public_key(@ssh_pub_key_file_path).fingerprint
      short_name = fingerprint[0, 12].gsub(/[^0-9a-zA-Z]/,'')
      return fingerprint, short_name
    end

    def get_mock_key_data
      key_data =
         {"keys" => {
           "cb490595" => {"fingerprint" => "cb:49:05:95:b4:42:1c:95:74:f7:2d:41:0d:f0:37:3b"},
           "96d90241" => {"fingerprint" => "96:d9:02:41:e1:cb:0d:ce:e5:3b:fc:da:13:65:3e:32"},
           "73ce2cc1" => {"fingerprint" => "73:ce:2c:c1:01:ea:79:cc:f6:be:86:45:67:96:7f:e3"}
         },
         "fingerprint" => "0f:97:4b:82:87:bb:c6:dc:40:a3:c1:bc:bb:55:1e:fa"}
    end

    def setup_mock_ssh_keys
      private_key_file = File.join(@ssh_dir, "id_rsa")
      public_key_file = File.join(@ssh_dir, "id_rsa.pub")
      File.open(private_key_file, 'w') do |f|
        f.write <<EOF
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

      File.open(public_key_file, 'w') do |f|
        f.write <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDIXpBBs7g93z/5JqW5IJNJR8bG6DWhpL2vR2ROEfzGqDHLZ+XbsaS/Ogc3nZNSav3juHWdiBFIc0unPpLdwmXtcL3tjN52CJqPgU/W0q061fL/tk77fFqW2upluo0ZRZQdPc3vTI3tWWZcpyE2LPHHUOI3KN+lRqxgw0Y6z/3Sfw== OpenShift-Key
EOF
      end
    end
  end

  class FirstRunWizardDriver < RHC::Wizard
    include WizardDriver
  end

  class RerunWizardDriver < RHC::RerunWizard
    include WizardDriver
  end
end
