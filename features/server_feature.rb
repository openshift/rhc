require 'spec_helper'
require 'direct_execution_helper'
require 'rhc/helpers'

describe "rhc server scenarios" do

  context "with standard config" do
    before(:all){ standard_config }

    it "should list the default server" do
      r = ensure_command 'servers'
      r.stdout.should match /Server 'server1' \(in use\)/
      r.stdout.should match /Hostname:\s+#{server}/
      r.stdout.should match /Login:\s+#{rhlogin}/
      r.stdout.should match /Use Auth Tokens:\s+true/
      r.stdout.should match /Insecure:\s+true/
      should_list_servers(1)
    end    

    it "should and and remove servers" do
      should_add_mock_servers(2)
      should_list_servers(3)
      should_remove_server('mock1')
      should_remove_server('mock2')
      should_list_servers(1)
    end
  end

  context "with a clean configuration" do
    before(:all){ use_clean_config }

    it "should add one working server" do
      should_list_servers(0)
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
        r.stdout.should match /You don't have any servers configured/
      else
        r.stdout.should match /You have #{RHC::Helpers.pluralize(quantity, 'server')} configured/
      end
      r
    end

    def should_add_mock_servers(quantity)
      Array(1..quantity).each do |i|
        new_server = "foo#{i}.openshift.com"
        new_user = "user#{i}"
        new_nickname = "mock#{i}"

        r = ensure_command 'server', 'add', new_server, new_nickname, '-l', new_user, '--skip-wizard'
        r.stdout.should match /Saving server configuration to .*servers\.yml .* done/

        r = ensure_command 'servers'
        r.stdout.should match /Server '#{new_nickname}'$/
        r.stdout.should match /Hostname:\s+#{new_server}/
        r.stdout.should match /Login:\s+#{new_user}/
      end
    end

    def should_add_working_server
      r = rhc 'server', 'add', server, '-l', rhlogin, '--insecure', :with => ['password', 'yes']
      r.stdout.should match /Saving configuration to .*express\.conf .* done/
      r.status.should == 0

      r = ensure_command 'servers'
      r.stdout.should match /Server 'server1' \(in use\)/
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