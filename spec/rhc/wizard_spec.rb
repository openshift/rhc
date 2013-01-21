require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/wizard'
require 'rhc/vendor/parseconfig'
require 'rhc/config'
require 'ostruct'
require 'rest_spec_helper'
require 'wizard_spec_helper'
require 'tmpdir'

# Allow to define the id method
OpenStruct.__send__(:define_method, :id) { @table[:id] } if RUBY_VERSION.to_f == 1.8

describe RHC::Wizard do

  def mock_config
    RHC::Config.stub(:home_dir).and_return('/home/mock_user')
  end

  let(:options){ (o = Commander::Command::Options.new).default(default_options); o }
  let(:config){ RHC::Config.new.tap{ |c| c.stub(:home_dir).and_return('/home/mock_user') } }
  let(:default_options){ {} }

  describe "#finalize_stage" do
    subject{ RHC::Wizard.new(config, options) }
    before{ subject.should_receive(:say).with(/The OpenShift client tools have been configured/) }
    it{ subject.send(:finalize_stage).should be_true }
  end

  describe "#login_stage" do
    let(:user){ 'test_user' }
    let(:password){ 'test pass' }
    let(:rest_client){ stub }
    let(:auth){ subject.send(:auth) }

    subject{ RHC::Wizard.new(config, options) }

    def expect_client_test
      subject.should_receive(:new_client_for_options).ordered.and_return(rest_client)
      rest_client.should_receive(:api).ordered
      rest_client.should_receive(:user).ordered.and_return(true)
    end
    def expect_raise_from_api(error)
      #subject.send(:auth).should_receive(:ask).with("Using #{user} to login to openshift.redhat.com").and_return(username).ordered
      #subject.send(:auth).should_receive(:ask).with("Password: ").and_return(password).ordered
      subject.should_receive(:new_client_for_options).ordered.and_return(rest_client)
      rest_client.should_receive(:api).ordered.and_raise(error)
    end

    it "should prompt for user and password" do
      #auth.should_receive(:ask).with("Login to openshift.redhat.com: ").ordered.and_return(user)
      #auth.should_receive(:ask).with("Password: ").ordered.and_return(password)
      expect_client_test

      subject.send(:login_stage).should be_true
    end

    context "with credentials" do
      let(:default_options){ {:rhlogin => user, :password => password} }

      it "should warn about a self signed cert error" do
        expect_raise_from_api(RHC::Rest::SelfSignedCertificate.new('reason', 'message'))
        subject.should_receive(:warn).with(/server's certificate is self-signed/).ordered
        subject.should_receive(:openshift_online_server?).ordered.and_return(true)
        subject.should_receive(:warn).with(/server between you and OpenShift/).ordered

        subject.send(:login_stage).should be_nil
      end

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
    subject{ RHC::RerunWizard.new(config, options) }

    before(:each) do
      mock_terminal
      FakeFS.activate!
      FakeFS::FileSystem.clear
      mock_config
      RHC::Config.initialize
    end

    after(:all) do
      FakeFS.deactivate!
    end

    #after{ FileUtils.rm_rf(@tmpdir) if @tmpdir }
    let(:home_dir){ '/home/mock_user' }#@tmpdir = Dir.mktmpdir }
    let(:config){ RHC::Config.new.tap{ |c| c.stub(:home_dir).and_return(home_dir) } }

    let(:options){ (o = Commander::Command::Options.new).default(default_options); o }
    let(:default_options){ {:server => mock_uri} }
    let(:username){ mock_user }
    let(:password){ 'password' }
    let(:user_auth){ {:user => username, :password => password} }

    describe "#run" do
      context "when a stage returns nil" do
        before{ subject.stub(:greeting_stage).and_return(nil) }
        it "should exit after that stage" do
          subject.should_receive(:login_stage).never
          subject.run.should be_nil
        end
      end
    end

    context "with no settings" do
      before do
        stub_api
        stub_user
        stub_no_keys
        stub_no_domains
        stub_simple_carts
      end

      it "should execute the minimal path" do
        should_greet_user
        should_challenge_for(username, password)
        should_write_config
        should_create_an_ssh_keypair
        should_skip_uploading_key
        should_find_git
        should_not_find_ssh_keys
        should_skip_creating_namespace
        should_list_types_of_apps_to_create
        should_be_done
      end

      context "on windows systems" do
        before{ subject.stub(:windows?).and_return(true) }
        it "should display windows info" do
          should_greet_user
          should_challenge_for(username, password)
          should_write_config
          should_create_an_ssh_keypair
          should_skip_uploading_key
          should_display_windows_info
        end
      end

      context "when the user enters a domain and uploads a key" do
        before do
          stub_create_default_key
          stub_api_request(:post, 'broker/rest/domains', user_auth).
            with(:body => /(thisnamespaceistoobig|invalidnamespace)/).
            to_return({
              :status => 409,
              :body => {
                :messages => [{:field => 'id', :severity => 'ERROR', :text => 'Too long', :exit_code => 123}]
              }.to_json
            })
          stub_create_domain('testnamespace')
        end
        it "should create the domain" do
          should_greet_user
          should_challenge_for(username, password)
          should_write_config
          should_create_an_ssh_keypair
          should_upload_default_key
          should_find_git
          should_not_find_ssh_keys
          should_create_a_namespace
          should_list_types_of_apps_to_create
          should_be_done
        end
      end

      context "when the user inputs incorrect authentication" do
        before{ stub_api_request(:get, 'broker/rest/user', :user => username, :password => 'invalid').to_return(:status => 401) }
        it "should prompt them again" do
          should_greet_user

          input_line username
          input_line 'invalid'
          input_line password
          next_stage.should_not be_nil

          last_output do |s|
            s.should match("Login to ")
            s.should match("Username or password is not correct")
            s.scan("Password: *").length.should == 2
          end
        end
      end

      context "when the default key is not uploaded" do
        before{ stub_one_key('a'); stub_update_key('a') }
        it "should prompt for the new key" do
          should_greet_user
          should_challenge_for(username, password)
          should_write_config
          should_create_an_ssh_keypair

          input_line 'yes'
          input_line 'a'
          next_stage
          last_output do |s|
            s.should match(/a \(type: ssh-rsa\)/)
            s.should match("Fingerprint: #{rsa_key_fingerprint_public}")
            s.should match(" name |a|")
          end
        end
      end

      context "when the default key already exists on the server" do
        before{ setup_mock_ssh(true) }
        before{ stub_mock_ssh_keys }

        it "should prompt for the new key" do
          should_greet_user
          should_challenge_for(username, password)
          should_write_config
          should_not_create_an_ssh_keypair
          should_find_matching_server_key
        end
      end
    end

    context "with login and existing domain and app" do
      let(:default_options){ {:rhlogin => username, :server => mock_uri} }
      subject{ RHC::RerunWizard.new(config, options) }

      before do
        stub_api(:user => username)
        stub_user
        stub_no_keys
        stub_create_default_key
        stub_api_request(:post, 'broker/rest/domains', user_auth).
          with(:body => /(thisnamespaceistoobig|invalidnamespace)/).
          to_return({
            :status => 409,
            :body => {
              :messages => [{:field => 'id', :severity => 'ERROR', :text => 'Too long', :exit_code => 123}]
            }.to_json
          })
        stub_one_domain('testnamespace')
        stub_one_application('testnamespace', 'test1')
        stub_simple_carts
      end

      it "should skip steps that have already been completed" do
        should_greet_user
        should_challenge_for(nil, password)
        should_write_config
        should_create_an_ssh_keypair
        should_upload_default_key
        should_not_find_git
        should_not_find_ssh_keys
        should_find_a_namespace('testnamespace')
        should_find_apps(['test1', 'testnamespace'])
        should_be_done
      end

      context "with different config" do
        let(:config_option){ setup_different_config }
        let(:default_options){ {:rhlogin => username, :server => mock_uri, :config => config_option} }

        it "should overwrite the config" do
          should_greet_user
          should_challenge_for(nil, password)
          should_overwrite_config
        end
      end
    end

    context "with SSHWizard" do
      let(:default_options){ {:rhlogin => username, :password => password} }
      let(:auth){ RHC::Auth::Basic.new(options) }
      let(:rest_client){ RHC::Rest::Client.new(:server => mock_uri, :auth => auth) }
      subject{ RHC::SSHWizard.new(rest_client, config, options) }

      before do
        stub_api(user_auth)
        stub_user
      end

      context "with no server keys" do
        before{ stub_no_keys }
        before{ stub_create_default_key }

        it "should generate and upload keys since the user does not have them" do
          input_line "yes"
          input_line 'default'
          input_line ""

          should_create_an_ssh_keypair
          should_upload_default_key

          #last_output.should match("Uploading key 'default'")
        end

        context "with default keys created" do
          before{ setup_mock_ssh(true) }
          it "should upload the default key" do
            should_not_create_an_ssh_keypair
            should_upload_default_key
          end
        end
      end

      context "with the server having the default key" do
        before{ setup_mock_ssh(true) }
        before{ stub_mock_ssh_keys }
        it "should pass through since the user has keys already" do
          subject.run.should be_true
          last_output.should == ""
        end
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

        output = last_output
        output.should match("Your ssh public key at .* is invalid or unreadable\.")
        @fallback_run.should be_true
      end

      it "should cause upload_ssh_key to catch NotImplementedError and return false" do
        wizard.ssh_keys = wizard.get_mock_key_data
        Net::SSH::KeyFactory.stub(:load_public_key) { raise NotImplementedError }

        wizard.send(:upload_ssh_key).should be_false

        output = last_output
        output.should match("Your ssh public key at .* is invalid or unreadable\.")
      end

      it "should match ssh key fallback fingerprint to net::ssh fingerprint" do
        # we need to write to a live file system so ssh-keygen can find it
        FakeFS.deactivate!
        Dir.mktmpdir do |dir|
          setup_mock_ssh_keys(dir)
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
          input_line "testnamespace" # try to add a namespace
          input_line '' # the above input will raise exception.
                                  # we now skip configuring namespace.
          wizard.send(:ask_for_namespace)
          output = last_output
          output.should match msg
        end

        it "should update the key correctly" do
          key_name = 'default'
          key_data = wizard.get_mock_key_data
          wizard.ssh_keys = key_data
          wizard.stub(:get_preferred_key_name) { key_name }
          wizard.stub(:ssh_key_triple_for_default_key) { pub_key.chomp.split }
          wizard.stub(:fingerprint_for_default_key) { "" } # this value is irrelevant
          wizard.rest_client.stub(:find_key) { key_data.detect { |k| k.name == key_name } }

          wizard.send(:upload_ssh_key)
          output = last_output
          output.should match 'Updating'
        end

        it 'should pick a usable SSH key name' do
          File.exists?('1').should be_false
          key_name = 'default'
          key_data = wizard.get_mock_key_data
          Socket.stub(:gethostname) { key_name }
          input_line("\n") # to accept default key name
          wizard.ssh_keys = key_data
          wizard.stub(:ssh_key_triple_for_default_key) { pub_key.chomp.split }
          wizard.stub(:fingerprint_for_default_key) { "" } # this value is irrelevant
          wizard.rest_client.stub(:add_key) { true }

          wizard.send(:upload_ssh_key)
          output = last_output
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
