require 'spec_helper'
require 'rhc/helpers'
require 'rhc/core_ext'

describe RHC::Helpers do
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
