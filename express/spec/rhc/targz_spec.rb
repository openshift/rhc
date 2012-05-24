require 'spec_helper'
require 'rhc/targz'

describe RHC::TarGz do

  context 'with simple compressed .tar.gz' do
    subject { File.expand_path('../assets/targz_sample.tar.gz', __FILE__) }
    it('should wrap the right filename') { File.basename(subject).should ==  'targz_sample.tar.gz' }
    it('should contain the right files') { RHC::TarGz.contains(subject, /foo/).should be_true }
    it('should contain the right files') { RHC::TarGz.contains(subject, /bar/).should be_false }
  end

  context 'with invalid .tar.gz file' do
    subject { File.expand_path('../assets/foo.txt', __FILE__) }
    it('should never contains') { RHC::TarGz.contains(subject, /bar/).should be_false }
  end

end
