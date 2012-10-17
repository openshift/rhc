require 'spec_helper'
require 'rhc/helpers'
require 'rhc/ssh_key_helpers'
require 'rhc/core_ext'
require 'highline/import'
require 'rhc/config'
require 'date'

describe RHC::Helpers do
  before(:each) do
    mock_terminal
    RHC::Config.set_defaults
    @tests = HelperTests.new()
  end

  subject do
    Class.new(Object) do
      include RHC::Helpers

      def config
        @config ||= RHC::Config
      end
    end.new
  end

  its(:openshift_server) { should == 'openshift.redhat.com' }
  its(:openshift_url) { should == 'https://openshift.redhat.com' }


  it("should pluralize many") { subject.pluralize(3, 'fish').should == '3 fishs' }
  it("should not pluralize one") { subject.pluralize(1, 'fish').should == '1 fish' }

  it("should decode json"){ subject.decode_json("{\"a\" : 1}").should == {'a' => 1} }

  it("should output green on success") do
    capture{ subject.success 'this is green' }.should == "\e[32mthis is green\e[0m"
  end
  it("should output yellow on warn") do
    capture{ subject.success 'this is yellow' }.should == "\e[32mthis is yellow\e[0m"
  end
  it("should return true on success"){ subject.success('anything').should be_true }
  it("should return true on success"){ subject.warn('anything').should be_true }

  it("should draw a table") do
    subject.table([[10,2], [3,40]]) do |i|
      i.map(&:to_s)
    end.should == ['10 2','3  40']
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
    it("should output the year for a date that is not this year") do
      older = now - 1*365*24*60
      subject.date(older.strftime(rfc3339)).should =~ /^[A-Z]/
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

  context "without RHC::Config" do
    subject do 
      Class.new(Object){ include RHC::Helpers }.new
    end

    it("should raise on config"){ expect{ subject.config }.should raise_error }
  end

  context "Formatter" do
    it "should print out a section without any line breaks" do
      @tests.section_no_breaks
      $terminal.read.should == "section 1 "
    end

    it "should print out a section with trailing line break" do
      @tests.section_one_break
      $terminal.read.should == "section 1\n"
    end

    it "should print out 2 sections with matching bottom and top margins generating one space between" do
      @tests.sections_equal_bottom_top
      $terminal.read.should == "section 1\n\nsection 2\n"
    end

    it "should print out 2 sections with larger bottom margin generating two spaces between" do
      @tests.sections_larger_bottom
      $terminal.read.should == "section 1\n\n\nsection 2\n"
    end

    it "should print out 2 sections with larger top margin generating two spaces between" do
      @tests.sections_larger_top
      $terminal.read.should == "section 1\n\n\nsection 2\n"
    end

    it "should print out 4 sections with the middle two on the same line and a space between the lines" do
      @tests.sections_four_on_three_lines
      $terminal.read.should == "section 1\n\nsection 2 section 3\n\nsection 4\n"
    end

    it "should show the equivilance of paragaph to section(:top => 1, :bottom => 1)" do
      @tests.section_1_1
      section_1_1 = $terminal.read
      @tests.reset
      @tests.section_paragraph
      paragraph = $terminal.read

      section_1_1.should == paragraph

      @tests.reset
      @tests.section_1_1
      @tests.section_paragraph

      $terminal.read.should == "\nsection\n\nsection\n\n"
    end

    it "should show two line with one space between even though an outside newline was printed" do
      @tests.outside_newline
      $terminal.read.should == "section 1\n\nsection 2\n"
    end
  end

  context "SSH Key Helpers" do
    it "should generate an ssh key then return nil when it tries to create another" do
      FakeFS do
        @tests.generate_ssh_key_ruby.should match("\.ssh/id_rsa\.pub")
        @tests.generate_ssh_key_ruby == nil
      end
    end
  end

  class HelperTests
    include RHC::Helpers
    include RHC::SSHKeyHelpers

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
      section {}
    end
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
