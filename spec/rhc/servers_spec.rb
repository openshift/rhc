require 'net/http'
require 'spec_helper'
require 'rhc/config'
require 'rhc/servers'

describe RHC::Servers do
  before do
    FakeFS.activate!
    FakeFS::FileSystem.clear
  end

  after do
    FakeFS.deactivate!
  end

  describe "servers class" do
    subject do
      RHC::Servers.new.tap do |s|
        s.stub(:path).and_return('/home/mock_user/servers.yml')
        s.stub(:load)
        s.instance_variable_set(:@servers, [
          RHC::Server.new(
            'openshift.server.com',
            :nickname => 'online',
            :login => 'user1',
            :use_authorization_tokens => true,
            :insecure => false)
        ])
      end
    end

    context "when finding server" do
      it "should find by nickname or hostname" do
        subject.send(:exists?, 'online').should be_true
        subject.send(:exists?, 'whatever').should be_false
        subject.send(:hostname_exists?, 'online').should be_false
        subject.send(:hostname_exists?, 'openshift.server.com').should be_true
        subject.send(:nickname_exists?, 'online').should be_true
        subject.send(:nickname_exists?, 'openshift.server.com').should be_false
        subject.send(:exists?, 'online').hostname.should == 'openshift.server.com'
        subject.send(:exists?, 'openshift.server.com').nickname.should == 'online'
        subject.send(:exists?, 'online').insecure.should == false
        subject.send(:exists?, 'online').use_authorization_tokens.should == true
        subject.find('online').should be_true
        subject.find('openshift.server.com').should be_true
        expect { subject.find('whatever') }.to raise_exception(RHC::ServerNotConfiguredException)
      end
    end

    context "when adding a new server" do
      before{ subject.add('another.server.com', :nickname => 'another', :login => 'user2', :use_authorization_tokens => false, :insecure => true) }
      it { subject.instance_variable_get(:@servers).length.should == 2 }
      it { subject.find('another').should be_true }
      it { subject.find('another.server.com').should be_true }
      it { subject.find('another').login.should == 'user2' }
      it { subject.find('another').insecure.should == true }
      it { subject.find('another').use_authorization_tokens.should == false }
    end

    context "when suggesting a nickname for unknown server" do
      before{ subject.add('another.server.com') }
      it { subject.find('server1').should be_true }
      it { subject.find('another.server.com').should be_true }
      it { subject.find('another.server.com').nickname.should == 'server1' }
    end

    context "when suggesting a nickname for an openshift subdomain" do
      before{ subject.add('some.openshift.redhat.com') }
      it { subject.find('some').should be_true }
      it { subject.find('some.openshift.redhat.com').should be_true }
      it { subject.find('some.openshift.redhat.com').nickname.should == 'some' }
    end

    context "when adding an existing server" do
      it "should error accordingly" do
        expect { subject.add('openshift.server.com') }.to raise_exception(RHC::ServerHostnameExistsException)
        expect { subject.add('openshift.server.com', :nickname => 'another') }.to raise_exception(RHC::ServerHostnameExistsException)
        expect { subject.add('third.server.com', :nickname => 'online') }.to raise_exception(RHC::ServerNicknameExistsException)
      end
    end

    context "when updating an existing server" do
      before{ subject.update('online', :hostname => 'openshift2.server.com', :nickname => 'online2', :login => 'user2', :use_authorization_tokens => false, :insecure => true) }
      it { subject.list.length.should == 1 }
      it { subject.find('online2').hostname.should == 'openshift2.server.com' }
      it { subject.find('online2').nickname.should == 'online2' }
      it { subject.find('online2').login.should == 'user2' }
      it { subject.find('online2').insecure.should == true }
      it { subject.find('online2').use_authorization_tokens.should == false }
      it { expect { subject.find('online') }.to raise_exception(RHC::ServerNotConfiguredException) }
    end

    context "when adding or updating a server" do
      before{ subject.add_or_update('openshift.server.com', :nickname => 'online2', :login => 'user2', :use_authorization_tokens => false, :insecure => true) }
      it { subject.list.length.should == 1 }
      it { subject.find('openshift.server.com').hostname.should == 'openshift.server.com' }
      it { subject.find('openshift.server.com').nickname.should == 'online2' }
      it { subject.find('openshift.server.com').login.should == 'user2' }
      it { subject.find('openshift.server.com').insecure.should == true }
      it { subject.find('openshift.server.com').use_authorization_tokens.should == false }
      it { expect { subject.find('online') }.to raise_exception(RHC::ServerNotConfiguredException) }
    end

    context "when removing an existing server" do
      before{ subject.remove('online') }
      it { subject.list.length.should == 0 }
      it { expect { subject.find('online') }.to raise_exception(RHC::ServerNotConfiguredException) }
    end

    context "when finding the default server" do
      it "should take the first if no default defined" do
        subject.default.nickname.should == 'online'
        subject.default.hostname.should == 'openshift.server.com'
      end
    end

    context "when finding the default server" do
      before do
        s = subject.add('another.server.com', :nickname => 'another', :login => 'user2', :use_authorization_tokens => false, :insecure => true)
        s.default = true
      end
      it "should take the one marked as default" do
        subject.default.nickname.should == 'another'
        subject.default.hostname.should == 'another.server.com'
      end
    end

    context "when sync from config" do
      before do
        c = RHC::Config.new
        c.instance_variable_set(:@opts, RHC::Vendor::ParseConfig.new.tap do |v|
          v.add('libra_server', 'openshift.server.com')
          v.add('default_rhlogin', 'user3')
        end)
        c.stub(:has_configs_from_files?).and_return(true)
        subject.sync_from_config(c) 
      end
      it { subject.list.length.should == 1 }
      it { subject.default.hostname.should == 'openshift.server.com' }
      it { subject.default.login.should == 'user3' }
    end
  end

  describe "server class" do
    subject do
      RHC::Server.from_yaml_hash({
        'hostname' => 'https://foo.com/bar', 
        'login' => 'user@foo.com', 
        'use_authorization_tokens' => 'true', 
        'insecure' => 'false'
      }) 
    end

    context "when creating from yaml hash" do
      it { subject.hostname.should == 'foo.com' }
      it { subject.nickname.should == nil }
      it { subject.login.should == 'user@foo.com' }
      it { subject.use_authorization_tokens.should be_true }
      it { subject.insecure.should be_false }
    end

    context "when checking server attributes" do
      it { subject.designation.should == 'foo.com' }
      it { subject.default?.should be_false }
      it { subject.to_yaml_hash.should == { 'hostname' => 'foo.com', 'login' => 'user@foo.com', 'use_authorization_tokens' => true, 'insecure' => false } }      
      it { subject.to_config.should be_a(RHC::Vendor::ParseConfig) }
      it { subject.to_config['default_rhlogin'].should == 'user@foo.com' }
      it { subject.to_config['libra_server'].should == 'foo.com' }
      it { subject.to_s.should == 'foo.com' }
    end

    context "when openshift online" do
      let(:server){ RHC::Server.from_yaml_hash({'hostname' => 'https://openshift.redhat.com', 'nickname' => 'online'}) }
      it { server.hostname.should == 'openshift.redhat.com' }
      it { server.nickname.should == 'online' }
      it { server.designation.should == 'online' }
      it { server.to_s.should == 'online (openshift.redhat.com)' }
    end
  end
end