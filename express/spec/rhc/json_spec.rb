require 'spec_helper'
require 'rhc/json'

describe RHC::Json do

  context 'with simple decoded hash as a string' do
    before { @decoded = RHC::Json.decode '{"abc":[123,-456.789e0],"def":[456,-456.789e0],"ghi":"ghj"}' }
    it('should contain all elements') { @decoded.length.should == 3  }
    it('should contain key') { @decoded.has_key?("abc").should == true  }
    it('should contain key') { @decoded.has_key?("def").should == true  }
    it('should contain key') { @decoded.has_key?("ghi").should == true  }
    it('should not contain invalid key') { @decoded.has_key?("ghj").should == false  }
    it('should contain value for key') { @decoded.has_value?("ghj").should == true  }
    it('should contain array value') { @decoded["abc"].is_a?(Array).should == true  }
    it('should contain array with two elements') { @decoded["abc"].length.should == 2  }
    it('should contain array with an integer') { @decoded["abc"][0].should == 123  }
    it('should contain array with a float') { @decoded["abc"][1].should == -456.789e0 }
    after { @decoded = nil }
  end

  context 'with simple hash' do
    before { @encoded = RHC::Json.encode({"key" => "value"}) }
    it('should encode to proper json') { @encoded.should == '{"key":"value"}'  }
    it('should encode and decode to the same hash') { RHC::Json.decode(@encoded).should == {"key" => "value"} }
    it('should decode and encode to the same string') { RHC::Json.encode(RHC::Json.decode('{"x":"y"}')).should == '{"x":"y"}' }
    after { @encoded = nil }
  end

end
