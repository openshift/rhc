require 'spec_helper'
require 'rhc/helpers'
require 'rhc/ssh_helpers'
require 'rhc/cartridge_helpers'
require 'rhc/git_helpers'
require 'rhc/core_ext'
require 'highline/import'
require 'rhc/config'
require 'rhc/helpers'
require 'date'

describe RHC::Helpers do
  before(:each) do
    mock_terminal
    RHC::Config.set_defaults
  end

  subject do
    Class.new(Object) do
      include RHC::Helpers
      include RHC::SSHHelpers

      def config
        @config ||= RHC::Config
      end
      def options
        @options ||= OpenStruct.new([:server])
      end
    end.new
  end
  let(:tests) { OutputTests.new }

  its(:openshift_server) { should == 'openshift.redhat.com' }
  its(:openshift_url) { should == 'https://openshift.redhat.com' }


  it("should pluralize many") { subject.pluralize(3, 'fish').should == '3 fishs' }
  it("should not pluralize one") { subject.pluralize(1, 'fish').should == '1 fish' }

  it("should decode json"){ subject.decode_json("{\"a\" : 1}").should == {'a' => 1} }

  it("should output green on success") do
    capture{ subject.success 'this is green' }.should == "\e[32mthis is green\e[0m\n"
  end
  it("should output yellow on warn") do
    capture{ subject.success 'this is yellow' }.should == "\e[32mthis is yellow\e[0m\n"
  end
  it("should return true on success"){ subject.success('anything').should be_true }
  it("should return true on success"){ subject.warn('anything').should be_true }

  it("should draw a table") do
    subject.table([[10,2], [3,40]]) do |i|
      i.map(&:to_s)
    end.should == ['10 2','3  40']
  end

  it("should output a table") do 
    subject.send(:display_no_info, 'test').should == ['This test has no information to show']
  end

  it "should parse an RFC3339 date" do
    d = subject.datetime_rfc3339('2012-06-24T20:48:20-04:00')
    d.day.should == 24
    d.month.should == 6
    d.year.should == 2012
  end

  context 'using the current time' do
    let(:now){ Time.now }
    let(:rfc3339){ '%Y-%m-%dT%H:%M:%S%z' }
    it("should output the time for a date that is today") do
      subject.date(now.strftime(rfc3339)).should =~ /^[0-9]/
    end
    it("should exlude the year for a date that is this year") do
      subject.date(now.strftime(rfc3339)).should_not match(now.year.to_s)
    end
    it("should output the year for a date that is not this year") do
      older = Date.today - 1*365
      subject.date(older.strftime(rfc3339)).should match(older.year.to_s)
    end
    it("should handle invalid input") do
      subject.date('Unknown date').should == 'Unknown date'
    end
  end

  context 'with LIBRA_SERVER environment variable' do
    before do
      ENV['LIBRA_SERVER'] = 'test.com'
      # need to reinit config to pick up env var
      RHC::Config.initialize
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

    it("should raise on config"){ expect{ subject.config }.should raise_error }
  end

  context "Formatter" do
    before{ tests.reset }

    it "should print out a paragraph with open endline on the same line" do
      tests.section_same_line
      $terminal.read.should == "section 1 word\n"
    end

    it "should print out a section without any line breaks" do
      tests.section_no_breaks
      $terminal.read.should == "section 1 \n"
    end

    it "should print out a section with trailing line break" do
      tests.section_one_break
      $terminal.read.should == "section 1\n"
    end

    it "should print out 2 sections with matching bottom and top margins generating one space between" do
      tests.sections_equal_bottom_top
      $terminal.read.should == "section 1\n\nsection 2\n"
    end

    it "should print out 2 sections with larger bottom margin generating two spaces between" do
      tests.sections_larger_bottom
      $terminal.read.should == "section 1\n\n\nsection 2\n"
    end

    it "should print out 2 sections with larger top margin generating two spaces between" do
      tests.sections_larger_top
      $terminal.read.should == "section 1\n\n\nsection 2\n"
    end

    it "should print out 4 sections and not collapse open sections" do
      tests.sections_four_on_three_lines
      $terminal.read.should == "section 1\n\nsection 2 \nsection 3\n\nsection 4\n"
    end

    it "should show the equivilance of paragaph to section(:top => 1, :bottom => 1)" do
      tests.section_1_1
      section_1_1 = $terminal.read
      tests.reset
      tests.section_paragraph
      paragraph = $terminal.read

      section_1_1.should == paragraph

      tests.reset
      tests.section_1_1
      tests.section_paragraph

      $terminal.read.should == "section\n\nsection\n"
    end

    it "should not collapse explicit newline sections" do
      tests.outside_newline
      $terminal.read.should == "section 1\n\n\nsection 2\n"
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

        it { capture{ expect{ subject.git_clone_repo("url", "repo") }.should raise_error(RHC::GitException) } }
        it { capture_all{ subject.git_clone_repo("url", "repo") rescue nil }.should match("fake git clone") }
        it { capture_all{ subject.git_clone_repo("url", "repo") rescue nil }.should match("fatal: error") }
      end

      context "directory is missing" do
        let(:stderr){ "fatal: destination path 'foo' already exists and is not an empty directory." }
        let(:exit_status){ 1 }

        it { capture{ expect{ subject.git_clone_repo("url", "repo") }.should raise_error(RHC::GitDirectoryExists) } }
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
  end

  class OutputTests
    include RHC::Helpers
    include RHC::SSHHelpers

    def initialize
      @print_num = 0
      @options = Commander::Command::Options.new
    end

    def config
      @config ||= RHC::Config
    end

    def next_print_num
      @print_num += 1
    end

    def output
      say "section #{next_print_num}"
    end

    def output_no_breaks
      say "section #{next_print_num} "
    end
    
    def section_same_line
      section { output_no_breaks; say 'word' }
    end

    def section_no_breaks
      section { output_no_breaks }
    end

    def section_one_break
      section { output }
    end

    def sections_equal_bottom_top
      section(:bottom => 1) { output }
      section(:top => 1) { output }
    end

    def sections_larger_bottom
      section(:bottom => 2) { output }
      section(:top => 1) { output }
    end

    def sections_larger_top
      section(:bottom => 1) { output }
      section(:top => 2) { output }
    end

    def sections_four_on_three_lines
      section { output }
      section(:top => 1) { output_no_breaks }
      section(:bottom => 1) { output }
      section(:top => 1) { output }
    end

    def outside_newline
      section(:bottom => -1) { output }
      say "\n"
      section(:top => 1) { output }
    end

    def section_1_1
      section(:top => 1, :bottom => 1) { say "section" }
    end

    def section_paragraph
      paragraph { say "section" }
    end

    # call section without output to reset spacing to 0
    def reset
      RHC::Helpers.send(:class_variable_set, :@@margin, nil)
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

describe HighLine do
  it "should wrap the terminal" do
    $terminal.wrap_at = 10
    say "Lorem ipsum dolor sit amet"
    output = $terminal.read
    output.should match "Lorem\nipsum\ndolor sit\namet"
  end
  it "should wrap the terminal" do
    $terminal.wrap_at = 16
    say "Lorem ipsum dolor sit amet"
    output = $terminal.read
    output.should match "Lorem ipsum\ndolor sit amet"
  end
  it "should not wrap the terminal" do
    $terminal.wrap_at = 50
    say "Lorem ipsum dolor sit amet"
    output = $terminal.read
    output.should match "Lorem ipsum dolor sit amet"
  end
  it "should wrap the terminal when using color codes" do
    $terminal.wrap_at = 10
    say $terminal.color("Lorem ipsum dolor sit amet Lorem ipsum dolor sit amet", :red)
    output = $terminal.read
    output.should match "Lorem\nipsum\ndolor sit\namet Lorem\nipsum\ndolor sit\namet"
  end
  it "should wrap the terminal with other escape characters" do
    $terminal.wrap_at = 10
    say "Lorem ipsum dolor sit am\eet"
    output = $terminal.read
    output.should match "Lorem\nipsum\ndolor sit\nam\eet"
  end
  it "should wrap the terminal when words are smaller than wrap length" do
    $terminal.wrap_at = 3
    say "Antidisestablishmentarianism"
    output = $terminal.read
    output.should match "Ant\nidi\nses\ntab\nlis\nhme\nnta\nria\nnis\nm"
  end
end

describe RHC::CartridgeHelpers do
  before(:each) do
    mock_terminal
  end

  subject do
    Class.new(Object) do
      include RHC::CartridgeHelpers

      def config
        @config ||= RHC::Config.new
      end
    end.new
  end

  describe '#find_cartridge' do
    let(:cartridges){ [] }
    let(:find_cartridges){ [] }
    let(:rest_obj) do
      Object.new.tap do |o|
        o.stub(:find_cartridges).and_return(find_cartridges)
        o.stub(:cartridges).and_return(cartridges)
      end
    end

    it { expect{ subject.find_cartridge(rest_obj, 'foo') }.should raise_error(RHC::CartridgeNotFoundException, 'Invalid cartridge specified: \'foo\'. No cartridges have been added to this app.') }
  end
end
