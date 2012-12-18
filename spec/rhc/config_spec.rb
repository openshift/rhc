require 'spec_helper'
require 'rhc/config'
require 'net/http'

describe RHC::Config do
  subject{ RHC::Config }
  before(:all) do
    ENV['LIBRA_SERVER'] = nil
    ENV['http_proxy'] = nil
    mock_terminal
    RHC::Config.stub(:home_dir).and_return('/home/mock_user')
    FakeFS.activate!
    FakeFS::FileSystem.clear
  end

  after(:all) do
    FakeFS.deactivate!
  end

  describe "class" do
    it("should raise when foo is invoked") { expect{ subject.method_missing(:foo) }.to raise_error(NoMethodError) }
    it("should invoke a method on default") { subject.username.should be subject.default.username }
  end

  context "Config default values with no files" do
    before(:each) do
      subject.initialize
    end

    it "should not have any configs" do
      subject.has_global_config?.should be_false
      subject.has_local_config?.should be_false
      subject.has_opts_config?.should be_false
    end

    it "should return openshift.redhat.com for the server" do
      subject['libra_server'].should == "openshift.redhat.com"
      subject.default_rhlogin.should be_nil
      subject.config_user("default@redhat.com")
      subject.default_rhlogin.should == "default@redhat.com"
    end
  end

  context "Config values with /etc/openshift/express.conf" do
    it "should have only a global config" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com", "global@redhat.com")
      subject.initialize
      subject.has_global_config?.should be_true
      subject.has_local_config?.should be_false
      subject.has_opts_config?.should be_false
    end

    it "should get values from the global config" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com",
                                                                     "global@redhat.com",
                                                                     {"random_value" => 12})
      subject.initialize

      subject['libra_server'].should == "global.openshift.redhat.com"
      subject.default_rhlogin.should == "global@redhat.com"
      subject['random_value'].should == "12"
      subject['non_value'].should be_nil

    end

    it "should have libra_server fallback to the default if not set in config" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path, nil,
                                                                     "global@redhat.com")
      subject.initialize

      subject['libra_server'].should == "openshift.redhat.com"
      subject.default_rhlogin.should == "global@redhat.com"
    end
  end

  context "With a mock home dir" do

    def stub_config
      config = RHC::Config.new
      RHC::Config.instance_variable_set(:@default, config)
      config.stub(:home_dir).and_return(ConfigHelper.home_dir)
      RHC::Config.stub(:new).and_return(config)
      RHC::Config.default.should == config
      config.read_config_files
    end

    context "Config values with ~/.openshift/express.conf" do
      it "should have global and local config" do
        ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com",
                                                                       "global@redhat.com")
        ConfigHelper.write_out_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'),
                                                "local.openshift.redhat.com","local@redhat.com")
        stub_config

        subject.home_conf_path.should == File.join(ConfigHelper.home_dir, '.openshift')
        subject.local_config_path.should == File.join(ConfigHelper.home_dir, '.openshift', 'express.conf')
        subject.has_global_config?.should be_true
        subject.has_local_config?.should be_true
        subject.has_opts_config?.should be_false
      end

      it "should get values from local config" do
        ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com",
                                                                       "global@redhat.com",
                                                                       {"random_value" => "12"})
        ConfigHelper.write_out_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'),
                                                "local.openshift.redhat.com",
                                                "local@redhat.com",
                                                {"random_value" => 11})
        stub_config

        subject['libra_server'].should == "local.openshift.redhat.com"
        subject.default_rhlogin.should == "local@redhat.com"
        subject['random_value'].should == "11"
        subject['non_value'].should be_nil
      end

      it "should fallback to the default or global if not set in config" do
        ConfigHelper.write_out_config(ConfigHelper.global_config_path, nil,
                                                                       "global@redhat.com")
        ConfigHelper.write_out_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'),
                                                nil,
                                                nil,
                                                {"random_value" => 11})
        stub_config

        subject['libra_server'].should == "openshift.redhat.com"
        subject.default_rhlogin.should == "global@redhat.com"
        subject['random_value'].should == "11"
      end
    end

    context "Config values with LIBRA_SERVER ENV set" do
      it "should get values from local config" do
        ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com",
                                                                       "global@redhat.com",
                                                                       {"random_value" => "12"})
        ConfigHelper.write_out_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'),
                                                "local.openshift.redhat.com",
                                                "local@redhat.com",
                                                {"random_value" => 11})
        ENV['LIBRA_SERVER'] = "env.openshift.redhat.com"

        stub_config
        subject.set_local_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'))

        subject['libra_server'].should == "env.openshift.redhat.com"
        subject.default_rhlogin.should == "local@redhat.com"
        subject['random_value'].should == "11"
        subject['non_value'].should be_nil
      end
    end

    context "Config values with options set" do
      it "should have global and local config" do
        ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com",
                                                                       "global@redhat.com")
        ConfigHelper.write_out_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'),
                                                "local.openshift.redhat.com","local@redhat.com")
        ConfigHelper.write_out_config(ConfigHelper.opts_config_path,
                                      "opts.openshift.redhat.com",
                                      "opts@redhat.com")
        stub_config
        subject.check_cpath({"config" => ConfigHelper.opts_config_path,
                                 "random_val" => "ok"})

        subject.has_global_config?.should be_true
        subject.has_local_config?.should be_true
        subject.has_opts_config?.should be_true
      end

      it "should get values from local config" do
        ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com",
                                                                       "global@redhat.com",
                                                                       {"random_value" => "12"})
        ConfigHelper.write_out_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'),
                                                "local.openshift.redhat.com",
                                                "local@redhat.com",
                                                {"random_value" => 11})
        ConfigHelper.write_out_config(ConfigHelper.opts_config_path,
                                      "opts.openshift.redhat.com",
                                      "opts@redhat.com",
                                      {"random_value" => 10})
        stub_config
        subject.check_cpath({"config" => ConfigHelper.opts_config_path,
                                 "random_val" => "ok"})

        subject['libra_server'].should == "opts.openshift.redhat.com"
        subject.default_rhlogin.should == "opts@redhat.com"
        subject['random_value'].should == "10"
        subject['non_value'].should be_nil
      end

      it "should fallback to the default or global or local if not set in config" do
        ConfigHelper.write_out_config(ConfigHelper.global_config_path, nil,
                                                                       "global@redhat.com")
        ConfigHelper.write_out_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'),
                                                nil,
                                                nil,
                                                {"random_value" => 11,
                                                 "local_value" => "local"})
        ConfigHelper.write_out_config(ConfigHelper.opts_config_path,
                                      nil,
                                      nil,
                                      {"random_value" => 10})
        stub_config
        subject.check_cpath({"config" => ConfigHelper.opts_config_path,
                                 "random_val" => "ok"})

        subject['libra_server'].should == "openshift.redhat.com"
        subject.default_rhlogin.should == "global@redhat.com"
        subject['random_value'].should == "10"
        subject['local_value'].should == "local"
      end
    end
  end

  context "Debug options" do
    after(:all) do
      FakeFS::FileSystem.clear
    end

    it "should show debug as false because nothing is set" do
      ConfigHelper.check_legacy_debug({}).should be_false
    end

    it "should show debug as 'true' because config is set" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path,
                                    nil,
                                    nil,
                                    {"debug" => "true"})
      subject.initialize
      ConfigHelper.check_legacy_debug({}).should == "true"
    end

    it "should show debug as false because config is set" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path,
                                    nil,
                                    nil,
                                    {"debug" => "false"})
      subject.initialize
      ConfigHelper.check_legacy_debug({}).should be_false
    end

    it "should show debug as true because config is set" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path,
                                    nil,
                                    nil,
                                    {"debug" => "true"})
      subject.initialize
      ConfigHelper.check_legacy_debug({"debug" => false}).should be_true
    end

    it "should show debug as true because opt is set" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path,
                                    nil,
                                    nil,
                                    {"debug" => "false"})
      subject.initialize
      ConfigHelper.check_legacy_debug({"debug" => true}).should be_true
    end
  end

  context "Proxy ENV variable parsing" do
    before do
      subject.initialize
      ['http_proxy','HTTP_PROXY'].each do |var|
        ENV[var] = nil
      end
    end

    it "should return a direct http connection" do
      subject.using_proxy?.should_not == true
    end

    ['http_proxy','HTTP_PROXY'].each do |var|
      it "should retrun a proxy http connection for #{var}" do
        ENV[var] = "fakeproxy.foo:8080"
        # returns a generic class so we check to make sure it is not a
        # Net::HTTP class and rely on simplecov to make sure the proxy
        # code path was run
        subject.using_proxy?.should == true
      end
    end

    context "it should have the correct values" do
      let(:vars){ subject.proxy_vars }
      before do
        ENV['http_proxy'] = "my_user:my_pass@fakeproxy.foo:8080"
      end

      {
        :user => 'my_user',
        :pass => 'my_pass',
        :address => 'fakeproxy.foo',
        :port => 8080
      }.each do |var,expected|
        it "for #{var}" do
          vars[var].should == expected
        end
      end
    end
  end

  context "Configuration file parsing" do
    it "should exit if config file can't be read" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path,
                                    "global.openshift.redhat.com",
                                    "global@redhat.com")
      subject.initialize
      RHC::Vendor::ParseConfig.stub(:new) { raise Errno::EACCES.new("Fake can't read file") }
      subject.stub(:exit) { |code| code }

      expect { subject.check_cpath({"config" => "fake.conf"}) }.to raise_error(Errno::EACCES)

      # write out config file so it exists but is not readable
      ConfigHelper.write_out_config("fake.conf",
                                    "global.openshift.redhat.com",
                                    "global@redhat.com")

      expect { subject.read_config_files }.to raise_error(Errno::EACCES)
      expect { subject.set_local_config("fake.conf") }.to raise_error(Errno::EACCES)
      expect { subject.set_opts_config("fake.conf") }.to raise_error(Errno::EACCES)
    end
  end
end

class ConfigHelper
  @@global_config_path = '/etc/openshift/express.conf'
  @@home_dir = '/home/mock_user'
  @@opts_config_path = File.join(@@home_dir, "my.conf")

  def self.global_config_path
    @@global_config_path
  end

  def self.home_dir
    @@home_dir
  end

  def self.opts_config_path
    @@opts_config_path
  end

  def self.check_legacy_debug(opts)
    # this simulates how the old rhc code checked for debug
    # in the future this should all be filtered through the Config module
    # and an app should just have to use subject.debug?
    debug = RHC::Config['debug'] == 'false' ? nil : RHC::Config['debug']
    debug = true if opts.has_key? 'debug'
    debug
  end

  def self.write_out_config(config_path, server, login, other={})
    FileUtils.mkdir_p File.dirname(config_path)
    File.open(config_path, "w") do |f|
      f.write "# This is a test file\n\n"
      f.write("libra_server = #{server}\n") unless server.nil?
      f.write("default_rhlogin = #{login}\n\n") unless login.nil?
      other.each { |key, value| f.write("#{key}=#{value}\n") }
    end
  end
end
