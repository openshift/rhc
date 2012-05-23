require 'spec_helper'
require 'rhc/json'

describe RHC::Json do

  context 'with simple decoded hash as a string' do
    subject { RHC::Json.decode '{"abc":[123,-456.789e0],"def":[456,-456.789e0],"ghi":"ghj"}' }
    its(:length) { should == 3 }
    it('should contain key') { subject.has_key?("abc").should be_true  }
    it('should contain key') { subject.has_key?("def").should be_true  }
    it('should contain key') { subject.has_key?("ghi").should be_true  }
    it('should not contain invalid key') { subject.has_key?("ghj").should be_false  }
    it('should contain value for key') { subject.has_value?("ghj").should be_true  }
    it('should contain array value') { subject["abc"].is_a?(Array).should be_true  }
    it('should contain array with two elements') { subject["abc"].length.should == 2  }
    it('should contain array with an integer') { subject["abc"][0].should == 123  }
    it('should contain array with a float') { subject["abc"][1].should == -456.789e0 }
  end

  context 'with simple hash' do
    subject { RHC::Json.encode({"key" => "value"}) }
    it('should encode to proper json') { subject.should == '{"key":"value"}'  }
    it('should encode and decode to the same hash') { RHC::Json.decode(subject).should == {"key" => "value"} }
    it('should decode and encode to the same string') { RHC::Json.encode(RHC::Json.decode('{"x":"y"}')).should == '{"x":"y"}' }
  end

end
