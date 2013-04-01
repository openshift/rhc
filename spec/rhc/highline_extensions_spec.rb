require 'spec_helper'

class OutputTests < SimpleDelegator
  def initialize(terminal)
    super
    @print_num = 0
  end

  [:say, :agree, :ask, :choose].each do |sym|
    define_method(sym) do |*args, &block|
      __getobj__.send(sym, *args, &block)
    end
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
    __getobj__.instance_variable_set(:@margin, 0)
  end
end


describe HighLine::Header do 
  it("should join a header"){ described_class.new("ab cd", 0).to_a.should == ["ab cd", '-----'] }
  it("should wrap a header"){ described_class.new("ab cd", 4).to_a.should == ["ab", "cd", '--'] }
  it("should wrap an array header"){ described_class.new(["ab cd"], 4).to_a.should == ["ab", "cd", '--'] }
  it("should combine an array header"){ described_class.new(["ab", "cd"], 5).to_a.should == ["ab cd", '-----'] }
  it("should wrap on array header boundaries"){ described_class.new(["abcd", "e"], 5).to_a.should == ["abcd", "e", '----'] }
  it("should indent an array header"){ described_class.new(["ab", "cd"], 4, ' ').to_a.should == ["ab", " cd", '---'] }
  it("should indent after a wrap"){ described_class.new(["ab cd", "ef gh", "ij"], 4, ' ').to_a.should == ["ab", "cd", " ef", " gh", " ij", '---'] }
end

describe HighLineExtension do
  subject{ MockHighLineTerminal.new }

  it("default_max_width should depend on wrap"){ subject.wrap_at = nil; subject.default_max_width.should be_nil}
  it("default_max_width should handle indentation"){ subject.wrap_at = 10; subject.indent{ subject.default_max_width.should == 7 } }

  it "should wrap the terminal" do
    subject.wrap_at = 10
    subject.say "Lorem ipsum dolor sit amet"
    output = subject.read
    output.should match "Lorem\nipsum\ndolor sit\namet\n"
  end
  it "should wrap the terminal" do
    subject.wrap_at = 16
    subject.say "Lorem ipsum dolor sit amet"
    output = subject.read
    output.should == "Lorem ipsum\ndolor sit amet\n"
  end
  it "should not wrap the terminal" do
    subject.wrap_at = 50
    subject.say "Lorem ipsum dolor sit amet"
    output = subject.read
    output.should == "Lorem ipsum dolor sit amet\n"
  end
  it "should wrap the terminal when using color codes" do
    subject.wrap_at = 10
    subject.say subject.color("Lorem ipsum dolor sit amet Lorem ipsum dolor sit amet", :red)
    output = subject.read
    output.should == "\e[31mLorem\e\[0m\nipsum\ndolor sit\namet Lorem\nipsum\ndolor sit\namet\e[0m\n"
  end
  it "should wrap the terminal with other escape characters" do
    subject.wrap_at = 10
    subject.say "Lorem ipsum dolor sit am\eet"
    output = subject.read
    output.should == "Lorem\nipsum\ndolor sit\nam\eet\n"
  end
  it "should wrap the terminal when words are smaller than wrap length" do
    subject.wrap_at = 3
    subject.say "Antidisestablishmentarianism"
    output = subject.read
    output.should == "Antidisestablishmentarianism\n"
  end

  it "should wrap a table based on a max width" do
    subject.table([["abcd efgh", "1234 6789 a"]], :width => 9, :heading => 'Test').to_a.should == [
      'Test',
      '----',
      "abcd 1234",
      "efgh 6789",
      "     a"
    ]
  end

  it "should allocate columns fairly in a table" do
    subject.table([["abcd", "12345 67890"]], :width => 10).to_a.should == [
      "abcd 12345",
      "     67890",
    ]
  end

  it "should not wrap without a width" do
    subject.table([["abcd", "12345 67890"]]).to_a.should == [
      "abcd 12345 67890",
    ]
  end
  it "should implement each_line on the table" do
    subject.table([["abcd", "12345 67890"]]).each_line.next.should == "abcd 12345 67890"
  end

  it "should display headers" do
    subject.table([["abcd", "12345 67890"]], :header => ['abcdef', '123'], :width => 12).to_a.should == [
      'abcdef 123',
      '------ -----',
      "abcd   12345",
      "       67890",
    ]
  end

  it "should add a header to a table" do
    subject.table([["abcd efgh", "1234 6789 a"]], :width => 9, :heading => "Alongtextstring").to_a.should == [
      "Alongtext",
      "string",
      "---------",
      "abcd 1234",
      "efgh 6789",
      "     a"
    ]
  end

  it "should indent a table" do
    subject.table([["abcd efgh", "1234 6789 a"]], :indent => ' ', :width => 10).to_a.should == [
      " abcd 1234",
      " efgh 6789",
      "      a"
    ]
  end

  it "should not wrap table when not enough minimum width" do
    subject.table([["ab cd", "12 34"]], :width => 4).to_a.should == [
      "ab cd 12 34", 
    ]
  end

  it "should not wrap table cells that are too wide based on a max width" do
    subject.table([["abcdefgh", "1234567890"]], :width => 8).to_a.should == [
      "abcdefgh 1234567890",
    ]
  end

  it "should force wrap a table based on columns" do
    subject.table([["ab cd", "123"]], :width => [2]).to_a.should == [
      "ab 123",
      "cd",
    ]
  end

  context "sections" do
    let(:tests) { OutputTests.new(subject) }

    it "should print out a paragraph with open endline on the same line" do
      tests.section_same_line
      subject.read.should == "section 1 word\n"
    end

    it "should print out a section without any line breaks" do
      tests.section_no_breaks
      subject.read.should == "section 1 \n"
    end

    it "should print out a section with trailing line break" do
      tests.section_one_break
      subject.read.should == "section 1\n"
    end

    it "should print out 2 sections with matching bottom and top margins generating one space between" do
      tests.sections_equal_bottom_top
      subject.read.should == "section 1\n\nsection 2\n"
    end

    it "should print out 2 sections with larger bottom margin generating two spaces between" do
      tests.sections_larger_bottom
      subject.read.should == "section 1\n\n\nsection 2\n"
    end

    it "should print out 2 sections with larger top margin generating two spaces between" do
      tests.sections_larger_top
      subject.read.should == "section 1\n\n\nsection 2\n"
    end

    it "should print out 4 sections and not collapse open sections" do
      tests.sections_four_on_three_lines
      subject.read.should == "section 1\n\nsection 2 \nsection 3\n\nsection 4\n"
    end

    it "should show the equivalence of paragaph to section(:top => 1, :bottom => 1)" do
      tests.section_1_1
      section_1_1 = tests.read
      
      tests = OutputTests.new(MockHighLineTerminal.new)

      tests.section_paragraph
      paragraph = tests.read

      section_1_1.should == paragraph
    end
    it "should combine sections" do
      tests.section_1_1
      tests.section_paragraph

      subject.read.should == "section\n\nsection\n"
    end

    it "should not collapse explicit newline sections" do
      tests.outside_newline
      subject.read.should == "section 1\n\n\nsection 2\n"
    end
  end
end