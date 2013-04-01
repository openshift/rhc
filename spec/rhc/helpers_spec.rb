require 'spec_helper'
require 'rhc'
require 'rhc/ssh_helpers'
require 'rhc/cartridge_helpers'
require 'rhc/git_helpers'
require 'rhc/core_ext'
require 'rhc/config'
require 'date'
require 'resolv'
require 'ostruct'

class MockHelpers
  include RHC::Helpers
  include RHC::SSHHelpers
  include RHC::CartridgeHelpers

  def config
    @config ||= RHC::Config.new
  end
  def options
    @options ||= OpenStruct.new(:server => nil)
  end
end

describe RHC::Helpers do
  before do
    mock_terminal
    user_config
  end

  subject{ MockHelpers.new }

  its(:openshift_server) { should == 'openshift.redhat.com' }
  its(:openshift_url) { should == 'https://openshift.redhat.com' }

  it("should display slashes"){ subject.system_path('foo/bar').should == 'foo/bar' }
  context "on windows" do
    it("should display backslashes"){ with_constants({:ALT_SEPARATOR => '\\'}, File) { subject.system_path('foo/bar').should == 'foo\\bar' } }
    it("should handle drives"){ with_constants({:ALT_SEPARATOR => '\\'}, File) { subject.system_path('C:/foo/bar').should == 'C:\\foo\\bar' } }
  end

  it("should pluralize many") { subject.pluralize(3, 'fish').should == '3 fishs' }
  it("should not pluralize one") { subject.pluralize(1, 'fish').should == '1 fish' }

  it("should decode json"){ subject.decode_json("{\"a\" : 1}").should == {'a' => 1} }

  shared_examples_for "colorized output" do
    it("should be colorized") do
      message = "this is #{_color} -"
      output = capture{ subject.send(method,message) }
      output.should be_colorized(message,_color)
    end
    it("should return true"){ subject.send(method,'anything').should be_true }
  end

  context "success output" do
    let(:_color){ :green }
    let(:method){ :success }
    it_should_behave_like "colorized output"
  end

  context "warn output" do
    let(:_color){ :yellow }
    let(:method){ :warn }
    it_should_behave_like "colorized output"
  end

  context "info output" do
    let(:_color){ :cyan }
    let(:method){ :info }
    it_should_behave_like "colorized output"
  end

  it("should invoke debug from debug_error"){ expect{ subject.debug_error(mock(:class => "Mock", :message => 'msg', :backtrace => [])) }.to call(:debug).on(subject).with("msg (Mock)\n  ") }

  it("should draw a table") do
    subject.table([[10,2], [3,40]]) do |i|
      i.map(&:to_s)
    end.to_a.should == ['10 2','3  40']
  end

  context "error output" do
    let(:_color){ :red }
    let(:method){ :error }
    it_should_behave_like "colorized output"
  end

  it("should output a table") do
    subject.send(:format_no_info, 'test').to_a.should == ['This test has no information to show']
  end

  it "should parse an RFC3339 date" do
    d = subject.datetime_rfc3339('2012-06-24T20:48:20-04:00')
    d.day.should == 24
    d.month.should == 6
    d.year.should == 2012
  end

  describe "#distance_of_time_in_words" do
    it{ subject.distance_of_time_in_words(0, 1).should == 'less than 1 minute' }
    it{ subject.distance_of_time_in_words(0, 60).should == '1 minute' }
    it{ subject.distance_of_time_in_words(0, 130).should == '2 minutes' }
    it{ subject.distance_of_time_in_words(0, 50*60).should == 'about 1 hour' }
    it{ subject.distance_of_time_in_words(0, 3*60*60).should == 'about 3 hours' }
    it{ subject.distance_of_time_in_words(0, 25*60*60).should == 'about 1 day' }
    it{ subject.distance_of_time_in_words(0, 3*24*60*60).should == '3 days' }
    it{ subject.distance_of_time_in_words(0, 40*24*60*60).should == 'about 1 month' }
    it{ subject.distance_of_time_in_words(0, 10*30*24*60*60).should == 'about 10 months' }
  end

  context 'using the current time' do
    let(:date){ Time.local(2008,1,2,1,1,0) }
    let(:today){ Date.new(2008,1,2) }
    before{ Date.stub(:today).and_return(today) }

    let(:rfc3339){ '%Y-%m-%dT%H:%M:%S%z' }
    it("should output the time for a date that is today") do
      subject.date(date.strftime(rfc3339)).should =~ /^[0-9]/
    end
    it("should exclude the year for a date that is this year") do
      subject.date(date.strftime(rfc3339)).should_not match(date.year.to_s)
    end
    it("should output the year for a date that is not this year") do
      older = Date.today - 1*365
      subject.date(older.strftime(rfc3339)).should match(older.year.to_s)
    end
    it("should handle invalid input") do
      subject.date('Unknown date').should == 'Unknown date'
    end

    context 'when the year is different' do
      let(:today){ Date.new(2007,1,2) }
      it{ subject.date(date.strftime(rfc3339)).should match(date.year.to_s) }
    end

    context 'when the year of the day is different' do
      let(:today){ Date.new(2008,1,1) }
      it{ subject.date(date.strftime(rfc3339)).should_not match(date.year.to_s) }
    end
  end

  context 'with LIBRA_SERVER environment variable' do
    before do
      ENV['LIBRA_SERVER'] = 'test.com'
      user_config
    end
    its(:openshift_server) { should == 'test.com' }
    its(:openshift_url) { should == 'https://test.com' }
    after { ENV['LIBRA_SERVER'] = nil }
  end
  context 'with --server environment variable' do
    before do
      subject.options.server = "test.com"
    end
    its(:openshift_server) { should == 'test.com' }
    its(:openshift_url) { should == 'https://test.com' }
    after { ENV['LIBRA_SERVER'] = nil }
  end

  context "without RHC::Config" do
    subject do
      Class.new(Object){ include RHC::Helpers }.new
    end

    it("should raise on config"){ expect{ subject.config }.to raise_error }
  end

  context "with a bad timeout value" do
    context "on the command line" do
      let(:arguments){ ['help', '--timeout=string'] }
      it{ expect{ run }.to exit_with_code(1) }
      it{ run_output.should match("invalid argument: --timeout=string") }
    end
    context "via the config" do
      before{ base_config{ |c, d| d.add 'timeout', 'string' } }
      let(:arguments){ ['help'] }
      it{ expect{ run }.to exit_with_code(1) }
      it{ run_output.should match(/The configuration file.*invalid setting: invalid value for Integer/) }
    end
  end
  context "with a valid client cert file" do
    let(:arguments){ ['help', '--ssl-client-cert-file=spec/keys/example.pem'] }
    it{ expect{ run }.to exit_with_code(0) }
  end

  context "with a missing client cert file" do
    context "on the command line" do
      let(:arguments){ ['help', '--ssl-client-cert-file=not_a_file'] }
      it{ expect{ run }.to exit_with_code(1) }
      it{ run_output.should match("The certificate 'not_a_file' cannot be loaded: No such") }
    end
    context "via the config" do
      before{ base_config{ |c, d| d.add 'ssl_client_cert_file', 'not_a_file' } }
      let(:arguments){ ['help'] }
      it{ expect{ run }.to exit_with_code(1) }
      it{ run_output.should match("The certificate 'not_a_file' cannot be loaded: No such") }
    end
  end

  context 'with a valid --ssl-version' do
    let(:arguments){ ['help', '--ssl-version=sslv3'] }

    context 'on an older version of HTTPClient' do
      before{ HTTPClient::SSLConfig.should_receive(:method_defined?).any_number_of_times.with(:ssl_version).and_return(false) }
      it('should print an error') { run_output.should =~ /You are using an older version of the httpclient.*--ssl-version/ }
      it('should error out') { expect{ run }.to exit_with_code(1) }
    end
    context 'a newer version of HTTPClient' do
      before{ HTTPClient::SSLConfig.should_receive(:method_defined?).any_number_of_times.with(:ssl_version).and_return(true) }
      it('should not print an error') { run_output.should_not =~ /You are using an older version of the httpclient.*--ssl-version/ }
      it('should error out') { expect{ run }.to exit_with_code(0) }
    end
  end

  context "with an invalid SSLVersion" do
    context "on the command line" do
      let(:arguments){ ['help', '--ssl-version=ssl'] }
      it{ expect{ run }.to exit_with_code(1) }
      it{ run_output.should match("The provided SSL version 'ssl' is not valid. Supported values: ") }
    end
    context "via the config" do
      before{ base_config{ |c, d| d.add 'ssl_version', 'ssl' } }
      let(:arguments){ ['help'] }
      it{ expect{ run }.to exit_with_code(1) }
      it{ run_output.should match("The provided SSL version 'ssl' is not valid. Supported values: ") }
    end
  end

  context "with an valid ssl CA file" do
    let(:arguments){ ['help', '--ssl-ca-file=spec/keys/example.pem'] }
    it{ expect{ run }.to exit_with_code(0) }
  end

  context "with an invalid ssl CA file" do
    let(:arguments){ ['help', '--ssl-ca-file=not_a_file'] }
    it{ expect{ run }.to exit_with_code(1) }
    it{ run_output.should match("The certificate 'not_a_file' cannot be loaded: No such file or directory ") }
  end

  context "#get_properties" do
    it{ subject.send(:get_properties, stub(:plan_id => 'free'), :plan_id).should == [[:plan_id, 'Free']] }
    context "when an error is raised" do
      let(:bar){ stub.tap{ |s| s.should_receive(:foo).and_raise(::Exception) } }
      it{ subject.send(:get_properties, bar, :foo).should == [[:foo, '<error>']] }
    end
  end

  context "Git Helpers" do
    subject{ Class.new(Object){ include RHC::Helpers; include RHC::GitHelpers; def debug?; false; end }.new }
    before{ subject.stub(:git_version){ raise "Fake Exception" } }
    its(:has_git?) { should be_false }

    context "git clone repo" do
      let(:stdout){ 'fake git clone' }
      let(:exit_status){ 0 }
      let!(:spawn) do
        out, err = stdout, stderr
        Open4.should_receive(:spawn).and_return(exit_status) do |cmd, opts|
          opts['stdout'] << out if out
          opts['stderr'] << err if err
          exit_status
        end
        true
      end

      it { capture{ subject.git_clone_repo("url", "repo").should be_true } }
      it { capture_all{ subject.git_clone_repo("url", "repo") }.should match("fake git clone") }

      context "does not succeed" do
        let(:stderr){ 'fatal: error' }
        let(:exit_status){ 1 }

        it { capture{ expect{ subject.git_clone_repo("url", "repo") }.to raise_error(RHC::GitException) } }
        it { capture_all{ subject.git_clone_repo("url", "repo") rescue nil }.should match("fake git clone") }
        it { capture_all{ subject.git_clone_repo("url", "repo") rescue nil }.should match("fatal: error") }
      end

      context "directory is missing" do
        let(:stderr){ "fatal: destination path 'foo' already exists and is not an empty directory." }
        let(:exit_status){ 1 }

        it { capture{ expect{ subject.git_clone_repo("url", "repo") }.to raise_error(RHC::GitDirectoryExists) } }
      end

      context "permission denied" do
        let(:stderr){ "Permission denied (publickey,gssapi-mic)." }
        let(:exit_status){ 1 }

        it { capture{ expect{ subject.git_clone_repo("url", "repo") }.to raise_error(RHC::GitPermissionDenied) } }
      end
    end
  end

  context "SSH Key Helpers" do
    it "should generate an ssh key then return nil when it tries to create another" do
      FakeFS do
        FakeFS::FileSystem.clear
        subject.generate_ssh_key_ruby.should match("\.ssh/id_rsa\.pub")
        subject.generate_ssh_key_ruby == nil
      end
    end

    it "should print an error when finger print fails" do
      Net::SSH::KeyFactory.should_receive(:load_public_key).with('1').and_raise(Net::SSH::Exception.new("An error"))
      subject.should_receive(:error).with('An error')
      subject.fingerprint_for_local_key('1').should be_nil
    end

    it "should catch exceptions from fingerprint failures" do
      Net::SSH::KeyFactory.should_receive(:load_public_key).with('1').and_raise(StandardError.new("An error"))
      subject.fingerprint_for_local_key('1').should be_nil
    end
  end

  describe "#wrap" do
    it{ "abc".wrap(1).should == "a\nb\nc" }
  end

  describe "#textwrap_ansi" do
    it{ "".textwrap_ansi(80).should == [] }
    it{ "\n".textwrap_ansi(80).should == ["",""] }
    it{ "a".textwrap_ansi(1).should == ['a'] }
    it{ "ab".textwrap_ansi(1).should == ['a','b'] }
    it{ "ab".textwrap_ansi(2).should == ['ab'] }
    it{ "ab cd".textwrap_ansi(4).should == ['ab', 'cd'] }
    it{ " ab".textwrap_ansi(2).should == [' a','b'] }
    it{ "a b".textwrap_ansi(1).should == ['a','b'] }
    it{ "a w b".textwrap_ansi(2).should == ['a','w','b'] }
    it{ "a w b".textwrap_ansi(3).should == ['a w','b'] }
    it{ "a\nb".textwrap_ansi(1).should == ['a','b'] }
    it{ "\e[1m".textwrap_ansi(1).should == ["\e[1m\e[0m"] }
    it{ "\e[31;1m".textwrap_ansi(1).should == ["\e[31;1m\e[0m"] }
    it{ "\e[1ma".textwrap_ansi(1).should == ["\e[1ma\e[0m"] }
    it{ "a\e[12m".textwrap_ansi(1).should == ["a\e[12m\e[0m"] }
    it{ "a\e[12m\e[34mb".textwrap_ansi(1).should == ["a\e[12m\e[34m\e[0m","b"] }
    it{ "\e[12;34ma".textwrap_ansi(1).should == ["\e[12;34ma\e[0m"] }
    it{ "\e[1m\e[1m".textwrap_ansi(1).should == ["\e[1m\e[1m\e[0m"] }
    it{ "\e[1m \e[1m".textwrap_ansi(1).should == ["\e[1m\e[0m", "\e[1m\e[0m"] }

    it{ "ab".textwrap_ansi(1,false).should == ['ab'] }
    it{ " abc".textwrap_ansi(3,false).should == [' abc'] }
    it{ "abcd".textwrap_ansi(3,false).should == ['abcd'] }
    it{ "abcd\e[1m".textwrap_ansi(3,false).should == ["abcd\e[1m\e[0m"] }
    it{ "abcd efg a".textwrap_ansi(3,false).should == ['abcd', 'efg', 'a'] }
    it('next line'){ "abcd e a".textwrap_ansi(5,false).should == ['abcd', 'e a'] }
    it{ "abcd efgh a".textwrap_ansi(3,false).should == ['abcd', 'efgh', 'a'] }
    it{ " abcd efg a".textwrap_ansi(3,false).should == [' abcd', 'efg', 'a'] }
  end

  describe "#strip_ansi" do
    it{ "\e[1m \e[1m".strip_ansi.should == " " }
  end

  context "Resolv helper" do
    let(:resolver) { Object.new }
    let(:existent_host) { 'real_host' }
    let(:nonexistent_host) { 'fake_host' }
    
    before :all do
      Resolv::Hosts.stub(:new) { resolver }
      resolver.stub(:getaddress).with(existent_host)   { existent_host }
      resolver.stub(:getaddress).with(nonexistent_host){ Resolv::ResolvError }
    end
    
    context "when hosts file has the desired host" do
      it "does not raise error" do
        expect {
          subject.hosts_file_contains?(existent_host)
        }.to_not raise_error
      end
    end

    context "when hosts file does not have the desired host" do
      it "does not raise error" do
        expect {
          subject.hosts_file_contains?(nonexistent_host)
        }.to_not raise_error
      end
    end
  end
end

describe RHC::Helpers::StringTee do
  let(:other){ StringIO.new }
  subject{ RHC::Helpers::StringTee.new(other) }
  context "It should copy output" do
    before{ subject << 'foo' }
    its(:string) { should == 'foo' }
    it("should tee to other") { other.string.should == 'foo' }
  end
end

describe Object do
  context 'present?' do
    specify('nil') { nil.present?.should be_false }
    specify('empty array') { [].present?.should be_false }
    specify('array') { [1].present?.should be_true }
    specify('string') { 'a'.present?.should be_true }
    specify('empty string') { ''.present?.should be_false }
  end

  context 'presence' do
    specify('nil') { nil.presence.should be_nil }
    specify('empty array') { [].presence.should be_nil }
    specify('array') { [1].presence.should == [1] }
    specify('string') { 'a'.presence.should == 'a' }
    specify('empty string') { ''.presence.should be_nil }
  end

  context 'blank?' do
    specify('nil') { nil.blank?.should be_true }
    specify('empty array') { [].blank?.should be_true }
    specify('array') { [1].blank?.should be_false }
    specify('string') { 'a'.blank?.should be_false }
    specify('empty string') { ''.blank?.should be_true }
  end
end

describe OpenURI do
  context 'redirectable?' do
    specify('http to https') { OpenURI.redirectable?(URI.parse('http://foo.com'), URI.parse('https://foo.com')).should be_true }
    specify('https to http') { OpenURI.redirectable?(URI.parse('https://foo.com'), URI.parse('http://foo.com')).should be_false }
  end
end

describe RHC::CartridgeHelpers do
  before(:each) do
    mock_terminal
  end

  subject{ MockHelpers.new }

  describe '#check_cartridges' do
    let(:cartridges){ [] }
    let(:find_cartridges){ [] }
    context "with a generic object" do
      it { expect{ subject.send(:check_cartridges, 'foo', :from => cartridges) }.to raise_error(RHC::CartridgeNotFoundException, 'There are no cartridges that match \'foo\'.') }
    end
  end
  describe '#web_carts_only' do
    it { expect{ subject.send(:web_carts_only).call([]) }.to raise_error(RHC::MultipleCartridgesException, /You must select only a single web/) }
  end

  describe '#match_cart' do
    context 'with a nil cart' do
      let(:cart){ OpenStruct.new(:name => nil, :description => nil, :tags => nil) }
      it{ subject.send(:match_cart, cart, 'foo').should be_false }
    end
    context 'with simple strings' do
      let(:cart){ OpenStruct.new(:name => 'FOO-more_max any', :description => 'bar', :tags => [:baz]) }
      it{ subject.send(:match_cart, cart, 'foo').should be_true }
      it{ subject.send(:match_cart, cart, 'fo').should be_true }
      it{ subject.send(:match_cart, cart, 'oo').should be_true }
      it{ subject.send(:match_cart, cart, 'bar').should be_true }
      it{ subject.send(:match_cart, cart, 'baz').should be_true }
      it{ subject.send(:match_cart, cart, 'more max').should be_true }
      it{ subject.send(:match_cart, cart, 'foo more max any').should be_true }
      it{ subject.send(:match_cart, cart, 'foo_more max-any').should be_true }
    end
  end
end
