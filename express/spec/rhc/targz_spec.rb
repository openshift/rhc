require 'spec_helper'
require 'rhc/targz'

describe RHC::TarGz do

  context 'with simple compressed .tar.gz' do
    before { @filename = File.expand_path('../assets/targz_sample.tar.gz', __FILE__) }
    it('should contain the right files') { RHC::TarGz.contains(@filename, /foo/).should == true }
    it('should contain the right files') { RHC::TarGz.contains(@filename, /bar/).should == false }
    after { @filename = nil }
  end

end
