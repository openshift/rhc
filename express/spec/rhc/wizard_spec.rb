require 'spec_helper'
require 'fakefs/spec_helpers'
require 'rhc/wizard'

describe RHC::Wizard do
  before(:each) do
    mock_terminal
  end

  context "First run of rhc" do
    include FakeFS::SpecHelpers
    before(:all) do
      @wizard = FirstRunWizardDriver.new
    end

    it "should print out first run greeting" do
      @wizard.run_next_stage
      greeting = $terminal.read
      greeting.count("\n").should == 8
      greeting.should match(Regexp.escape("It looks like you've not used OpenShift on this machine"))
      greeting.should match(Regexp.escape("\n#{@wizard.config_path}\n"))
    end

    it "should ask for login and hide password input" do
      # queue up input
      $terminal.write_line "#{@wizard.mock_user}"
      $terminal.write_line "password"
      @wizard.run_next_stage

      output = $terminal.read
      output.should match("OpenShift login")
      output.should end_with("*******\n\n")
    end

    it "should write out a config" do

    end

    it "should write ount generated ssh keys" do

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
    include FakeFS::SpecHelpers

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
    include FakeFS::SpecHelpers

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
    include FakeFS::SpecHelpers

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
    include FakeFS::SpecHelpers

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
    include FakeFS::SpecHelpers

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
    attr_accessor :mock_user, :libra_server, :config_path
    def initialize
      super '/home/mock_user/.openshift/openshift.conf'
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
