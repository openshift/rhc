require 'spec_helper'
require 'direct_execution_helper'
require 'rhc/helpers'

describe "rhc server scenarios" do
  context "with one existing server" do
    before(:each) do
      standard_config
    end
    after(:each) do
      use_clean_config
    end

    it "should list the default server" do
      environment(:standard) do
        r = ensure_command 'servers'
        r.stdout.should match /Server '#{server}' \(in use\)/
        r.stdout.should match /Hostname:\s+#{server}/
        r.stdout.should match /Login:\s+#{rhlogin}/
        r.stdout.should match /Use Auth Tokens:\s+true/
        r.stdout.should match /Insecure:\s+true/
        should_list_servers(1)
      end
    end    

    it "should add a second server" do
      environment(:standard) do
        should_add_mock_servers(1)
        should_list_servers(2)
      end
    end

    it "should and and remove servers" do
      environment(:standard) do
        should_add_mock_servers(2)
        should_list_servers(3)
        should_remove_server('server1')
        should_list_servers(2)
      end
    end
  end

  context "with clean config" do
    before(:each) do
      use_clean_config
    end
    after(:each) do
      use_clean_config
    end

    it "should not list any server" do
      should_list_servers(0)
    end
  end

  context "with clean config and using a working server" do
    before(:all) do
      use_clean_config
    end
    after(:all) do
      use_clean_config
    end

    it "should add one working server" do
      should_add_working_server
      should_list_servers(1)
    end
  end

  private
    def ensure_command(*args)
      r = rhc *args
      r.status.should == 0
      r
    end

    def should_list_servers(quantity)
      r = ensure_command 'servers'
      if quantity == 0
        r.stdout.should match /You don't have servers configured/
      else
        r.stdout.should match /You have #{RHC::Helpers.pluralize(quantity, 'server')} configured/
      end
      r
    end

    def should_add_mock_servers(quantity)
      Array(1..quantity).each do |i|
        new_server = "foo#{i}.openshift.com"
        new_user = "user#{i}"
        new_nickname = "server#{i}"

        r = ensure_command 'server', 'add', new_server, new_nickname, '-l', new_user, '--skip-wizard'
        r.stdout.should match /Saving server configuration to .*servers\.yml .* done/

        r = ensure_command 'servers'
        r.stdout.should match /Server '#{new_nickname}'$/
        r.stdout.should match /Hostname:\s+#{new_server}/
        r.stdout.should match /Login:\s+#{new_user}/
      end
    end

    def should_add_working_server
      nickname = 'localhost'
      r = rhc 'server', 'add', server, nickname, '-l', rhlogin, '--insecure', :with => ['password', 'yes']
      r.stdout.should match /Saving configuration to .*express\.conf .* done/
      r.status.should == 0

      r = ensure_command 'servers'
      r.stdout.should match /Server '#{nickname}' \(in use\)/
      r.stdout.should match /Hostname:\s+#{server}/
      r.stdout.should match /Login:\s+#{rhlogin}/
      r.stdout.should match /Use Auth Tokens:\s+true/
      r.stdout.should match /Insecure:\s+true/
    end

    def should_remove_server(server)
      r = ensure_command 'server', 'remove', server
      r.stdout.should match /Removing.*done/
      r
    end

    def server
      ENV['RHC_SERVER'] || 'localhost'
    end

    def rhlogin
      ENV['TEST_USERNAME']
    end
  end