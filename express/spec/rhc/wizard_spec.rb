require 'spec_helper'
require 'fakefs/spec_helpers'

describe RHC::Wizard do
  before(:each) do
    mock_terminal
  end

  context "First run of rhc" do
    include FakeFS::SpecHelpers

    it "should print out first run greeting" do

    end

    it "should ask for login and hide password input" do

    end

    it "should write out a config" do

    end

    it "should write out generated ssh keys" do

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
end
