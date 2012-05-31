require 'spec_helper'
require 'fakefs/safe'
require 'rhc/wizard'
require 'parseconfig'
require 'rhc/config'

# monkey patch ParseConfig so it works with fakefs
# TODO: if this is useful elsewhere move to helpers
class ParseConfig
  def open(*args)
    File.open *args
  end
end

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
      # queue up input
      $terminal.write_line "#{@wizard.mock_user}"
      $terminal.write_line "password"

      @wizard.stub_user_info
      @wizard.stub_rest_api

      @wizard.run_next_stage

      output = $terminal.read
      output.should match("OpenShift login")
      output.should =~ /(#{Regexp.escape("Password: ********\n")})$/
    end

    it "should write out a config" do
      File.exists?(@wizard.config_path).should be false
      @wizard.run_next_stage
      File.readable?(@wizard.config_path).should be true
      cp = ParseConfig.new @wizard.config_path
      cp.get_value("default_rhlogin").should == @wizard.mock_user
      cp.get_value("libra_server").should == @wizard.libra_server
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

    it "should upload ssh keys" do
      @wizard.stub_ssh_keys
      # don't upload
      $terminal.write_line('no')
      @wizard.run_next_stage
    end

    it "should check for client tools" do

    end

    it "should ask for a namespace" do

    end

    it "should show app creation commands" do

    end

    it "should show a thank you message" do

    end
  end

  context "Repeat run of rhc setup without anything set" do


    it "should print out repeat run greeting" do

    end

    it "should ask for login and hide password input" do

    end

    it "should write out a config" do

    end

    it "should write out generated ssh keys" do

    end

    it "should upload ssh key as default" do

    end

    it "should check for client tools and print they need to be installed" do

    end

    it "should ask for a namespace" do

    end

    it "should show app creation commands" do

    end

    it "should show a thank you message" do

    end
  end

  context "Repeat run of rhc setup with config set" do

    it "should print out repeat run greeting" do

    end

    it "should ask for password input (no login)" do

    end

    it "should write out generated ssh keys" do

    end

    it "should find out that you do not have not uploaded the keys and ask to name the key" do

    end

    it "should check for client tools and find them" do

    end

    it "should ask for a namespace" do

    end

    it "should show app creation commands" do

    end

    it "should show a thank you message" do

    end
  end

  context "Repeat run of rhc setup with config and ssh keys set" do

    it "should print out repeat run greeting" do

    end

    it "should ask for password input (no login)" do

    end

    it "should check for ssh tools and find a match" do

    end

    it "should check for client tools and find them" do

    end

    it "should ask for a namespace" do

    end

    it "should show app creation commands" do

    end

    it "should show a thank you message" do

    end
  end

  context "Repeat run of rhc setup with everything set" do

    it "should print out repeat run greeting" do

    end

    it "should ask password input (not login)" do

    end

    it "should check for ssh keys and find they are uploaded" do

    end

    it "should check for client tools and find them" do

    end

    it "should show namespace" do

    end

    it "should list apps" do

    end

    it "should show a thank you message" do

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

  module WizardDriver
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

    def stub_user_info
      data = {:ssh_key => "",
              :ssh_key_type => "",
              :rhlogin => @mock_user,
             }

      data = RHC::json_encode(data)
      stub_request(:post, "https://#{@libra_server}/broker/userinfo").to_return(:status => 200, :body => RHC::json_encode({:data => data}), :headers => {})
    end

    def stub_rest_api
      body = {
        "data" => {
          "LIST_ESTIMATES" => {
            "optional_params" => [],
            "rel" => "List available estimates",
            "method" => "GET",
            "href" => "https => //@{libra_server}/broker/rest/estimates",
            "required_params" => []
          },
          "API" => {"optional_params" => [],
            "rel" => "API entry point",
            "method" => "GET",
            "href" => "https => //#{libra_server}/broker/rest/api",
            "required_params" => []
          },
          "LIST_CARTRIDGES" => {
            "optional_params" => [],
            "rel" => "List cartridges",
            "method" => "GET","href" => "https => //@{libra_server}/broker/rest/cartridges",
            "required_params" => []
          },
          "GET_USER" => {
            "optional_params" => [],
            "rel" => "Get user information",
            "method" => "GET",
            "href" => "https => //#{libra_server}/broker/rest/user",
            "required_params" => []
          },
          "LIST_DOMAINS" => {
            "optional_params" => [],
            "rel" => "List domains",
            "method" => "GET",
            "href" => "https => //@libra_server/broker/rest/domains",
            "required_params" => []
          },
          "LIST_TEMPLATES" => {
            "optional_params" => [],
            "rel" => "List application templates",
            "method" => "GET",
            "href" => "https => //@{libra_server}/broker/rest/application_template",
            "required_params" => []
          },
          "ADD_DOMAIN" => {
            "optional_params" => [],
            "rel" => "Create new domain",
            "method" => "POST",
            "href" => "https => //@{libra_server}/broker/rest/domains",
            "required_params" => [
              {"description" => "Name of the domain",
               "valid_options" => [],
               "type" => "string",
               "name" => "id"
              }
            ]
          }
        },
        "version" => "1.0",
        "type" => "links",
        "supported_api_versions" => ["1.0"],
        "messages" => [],
        "status" => "ok"
      }

      stub_request(:get, "https://mock_user%40foo.bar:password@mock.openshift.redhat.com/broker/rest/api").to_return(:status => 200, :body => RHC::json_encode(body), :headers => {})
    end

    def stub_ssh_keys
      # TODO: add ssh keys if requests
      data = {:ssh_key => "",
              :keys => []
             }

      data = RHC::json_encode(data)
      stub_request(:post, "https://#{@libra_server}/broker/ssh_keys").to_return(:status => 200, :body => RHC::json_encode({:data => data}))
    end

    def setup_mock_config
      FileUtils.mkdir_p File.dirname(@config_path)
      File.open(@config_path, "w") do |file|
        file.puts <<EOF
# Default user login
default_rhlogin='#{@mock_user}'

# Server API
libra_server = '#{@libra_server}'
EOF
      end
    end

    def setup_mock_ssh(add_ssh_key=false)
      FileUtils.mkdir_p @ssh_dir
      if add_ssh_key
        #TODO: add and ssh key to the directory
      end
    end

    def has_git?
      @mock_git_installed
    end

    def has_package_kit?
      @mock_package_kit_installed
    end

    def windows?
      @platform_windows
    end
  end

  class FirstRunWizardDriver < RHC::Wizard
    include WizardDriver
  end

  class RerunWizardDriver < RHC::RerunWizard
    include WizardDriver
  end
end
