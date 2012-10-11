require 'spec_helper'
require 'rhc/config'
require 'net/http'

describe RHC::Config do
  before(:all) do
    ENV['LIBRA_SERVER'] = nil
    ENV['http_proxy'] = nil
    mock_terminal
    FakeFS.activate!
  end

  after(:all) do
    FakeFS::FileSystem.clear
    FakeFS.deactivate!
  end

  describe "class" do
    subject{ RHC::Config }
    it("should raise when foo is invoked") { expect{ RHC::Config.method_missing(:foo) }.to raise_error(NoMethodError) }
    it("should invoke a method on default") { RHC::Config.username.should be RHC::Config.default.username }
  end

  context "Config default values with no files" do
    before(:each) do
      RHC::Config.initialize
    end

    it "should not have any configs" do
      RHC::Config.has_global_config?.should be_false
      RHC::Config.has_local_config?.should be_false
      RHC::Config.has_opts_config?.should be_false
    end

    it "should return openshift.redhat.com for the server" do
      RHC::Config['libra_server'].should == "openshift.redhat.com"
      RHC::Config.default_rhlogin.should be_nil
      RHC::Config.config_user("default@redhat.com")
      RHC::Config.default_rhlogin.should == "default@redhat.com"
    end
  end

  context "Config values with /etc/openshift/express.conf" do
    it "should have only a global config" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com", "global@redhat.com")
      RHC::Config.initialize
      RHC::Config.has_global_config?.should be_true
      RHC::Config.has_local_config?.should be_false
      RHC::Config.has_opts_config?.should be_false
    end

    it "should get values from the global config" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com",
                                                                     "global@redhat.com",
                                                                     {"random_value" => 12})
      RHC::Config.initialize

      RHC::Config['libra_server'].should == "global.openshift.redhat.com"
      RHC::Config.default_rhlogin.should == "global@redhat.com"
      RHC::Config['random_value'].should == "12"
      RHC::Config['non_value'].should be_nil

    end

    it "should have libra_server fallback to the default if not set in config" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path, nil,
                                                                     "global@redhat.com")
      RHC::Config.initialize

      RHC::Config['libra_server'].should == "openshift.redhat.com"
      RHC::Config.default_rhlogin.should == "global@redhat.com"
    end
  end

  context "Config values with ~/.openshift/express.conf" do
    it "should have global and local config" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com",
                                                                     "global@redhat.com")
      ConfigHelper.write_out_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'),
                                              "local.openshift.redhat.com","local@redhat.com")
      RHC::Config.initialize
      RHC::Config.home_dir = ConfigHelper.home_dir

      RHC::Config.home_conf_path.should == File.join(ConfigHelper.home_dir, '.openshift')
      RHC::Config.local_config_path.should == File.join(ConfigHelper.home_dir, '.openshift', 'express.conf')
      RHC::Config.has_global_config?.should be_true
      RHC::Config.has_local_config?.should be_true
      RHC::Config.has_opts_config?.should be_false
    end

    it "should get values from local config" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path, "global.openshift.redhat.com",
                                                                     "global@redhat.com",
                                                                     {"random_value" => "12"})
      ConfigHelper.write_out_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'),
                                              "local.openshift.redhat.com",
                                              "local@redhat.com",
                                              {"random_value" => 11})
      RHC::Config.initialize
      RHC::Config.home_dir = ConfigHelper.home_dir

      RHC::Config['libra_server'].should == "local.openshift.redhat.com"
      RHC::Config.default_rhlogin.should == "local@redhat.com"
      RHC::Config['random_value'].should == "11"
      RHC::Config['non_value'].should be_nil
    end

    it "should fallback to the default or global if not set in config" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path, nil,
                                                                     "global@redhat.com")
      ConfigHelper.write_out_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'),
                                              nil,
                                              nil,
                                              {"random_value" => 11})
      RHC::Config.initialize
      RHC::Config.home_dir = ConfigHelper.home_dir

      RHC::Config['libra_server'].should == "openshift.redhat.com"
      RHC::Config.default_rhlogin.should == "global@redhat.com"
      RHC::Config['random_value'].should == "11"
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
      RHC::Config.initialize
      RHC::Config.set_local_config(File.join(ConfigHelper.home_dir,'.openshift', 'express.conf'))

      RHC::Config['libra_server'].should == "env.openshift.redhat.com"
      RHC::Config.default_rhlogin.should == "local@redhat.com"
      RHC::Config['random_value'].should == "11"
      RHC::Config['non_value'].should be_nil
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
      RHC::Config.initialize
      RHC::Config.home_dir = ConfigHelper.home_dir
      RHC::Config.check_cpath({"config" => ConfigHelper.opts_config_path,
                               "random_val" => "ok"})

      RHC::Config.has_global_config?.should be_true
      RHC::Config.has_local_config?.should be_true
      RHC::Config.has_opts_config?.should be_true
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
      RHC::Config.initialize
      RHC::Config.home_dir = ConfigHelper.home_dir
      RHC::Config.check_cpath({"config" => ConfigHelper.opts_config_path,
                               "random_val" => "ok"})

      RHC::Config['libra_server'].should == "opts.openshift.redhat.com"
      RHC::Config.default_rhlogin.should == "opts@redhat.com"
      RHC::Config['random_value'].should == "10"
      RHC::Config['non_value'].should be_nil
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
      RHC::Config.initialize
      RHC::Config.home_dir = ConfigHelper.home_dir
      RHC::Config.check_cpath({"config" => ConfigHelper.opts_config_path,
                               "random_val" => "ok"})

      RHC::Config['libra_server'].should == "openshift.redhat.com"
      RHC::Config.default_rhlogin.should == "global@redhat.com"
      RHC::Config['random_value'].should == "10"
      RHC::Config['local_value'].should == "local"
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
      RHC::Config.initialize
      ConfigHelper.check_legacy_debug({}).should == "true"
    end

    it "should show debug as false because config is set" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path,
                                    nil,
                                    nil,
                                    {"debug" => "false"})
      RHC::Config.initialize
      ConfigHelper.check_legacy_debug({}).should be_false
    end

    it "should show debug as true because config is set" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path,
                                    nil,
                                    nil,
                                    {"debug" => "true"})
      RHC::Config.initialize
      ConfigHelper.check_legacy_debug({"debug" => false}).should be_true
    end

    it "should show debug as true because opt is set" do
      ConfigHelper.write_out_config(ConfigHelper.global_config_path,
                                    nil,
                                    nil,
                                    {"debug" => "false"})
      RHC::Config.initialize
      ConfigHelper.check_legacy_debug({"debug" => true}).should be_true
    end
  end

  context "Proxy ENV variable parsing" do
    before do
      RHC::Config.initialize
      ['http_proxy','HTTP_PROXY'].each do |var|
        ENV[var] = nil
      end
    end

    it "should return a direct http connection" do
      RHC::Config.using_proxy?.should_not == true
    end

    ['http_proxy','HTTP_PROXY'].each do |var|
      it "should retrun a proxy http connection for #{var}" do
        ENV[var] = "fakeproxy.foo:8080"
        # returns a generic class so we check to make sure it is not a
        # Net::HTTP class and rely on simplecov to make sure the proxy
        # code path was run
        RHC::Config.using_proxy?.should == true
      end
    end

    context "it should have the correct values" do
      let(:vars){ RHC::Config.proxy_vars }
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
      RHC::Config.initialize
      RHC::Vendor::ParseConfig.stub(:new) { raise Errno::EACCES.new("Fake can't read file") }
      RHC::Config.stub(:exit) { |code| code }

      expect { RHC::Config.check_cpath({"config" => "fake.conf"}) }.to raise_error(Errno::EACCES)

      # write out config file so it exists but is not readable
      ConfigHelper.write_out_config("fake.conf",
                                    "global.openshift.redhat.com",
                                    "global@redhat.com")

      expect { RHC::Config.read_config_files }.to raise_error(Errno::EACCES)
      expect { RHC::Config.set_local_config("fake.conf") }.to raise_error(Errno::EACCES)
      expect { RHC::Config.set_opts_config("fake.conf") }.to raise_error(Errno::EACCES)
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
    # and an app should just have to use RHC::Config.debug?
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
