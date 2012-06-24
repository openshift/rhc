require 'spec_helper'
require 'rhc/targz'

describe RHC::TarGz do

  context 'with simple compressed .tar.gz' do
    subject { File.expand_path('../assets/targz_sample.tar.gz', __FILE__) }
    it('should wrap the right filename') { File.basename(subject).should ==  'targz_sample.tar.gz' }
    it('should contain the right files') { RHC::TarGz.contains(subject, 'foo').should be_true }
    it('should contain the right files') { RHC::TarGz.contains(subject, 'bar').should be_false }
    it('should contain the right files') { RHC::TarGz.contains(subject, 'test').should be_false }
    it('should contain the right files') { RHC::TarGz.contains(subject, 'foo').should be_true }
    it('should contain the right files') { RHC::TarGz.contains(subject, 'bar').should be_false }
    it('should contain the right files') { RHC::TarGz.contains(subject, 'test').should be_false }
  end

  context 'with file extension different than .tar.gz' do
    subject { File.expand_path('../assets/foo.txt', __FILE__) }
    it('should never return contains') { RHC::TarGz.contains(subject, 'foo').should be_false }
    it('should never return contains') { RHC::TarGz.contains(subject, 'foo', true).should be_false }
  end

  context 'with corrupted .tar.gz' do
    subject { File.expand_path('../assets/targz_corrupted.tar.gz', __FILE__) }
    it('should never return contains') { RHC::TarGz.contains(subject, 'foo').should be_false }
    it('should never return contains') { RHC::TarGz.contains(subject, 'foo', true).should be_false }
  end

  context 'with multiple threads' do
    subject { File.expand_path('../assets/targz_sample.tar.gz', __FILE__) }
    it('should be able to handle the same file') {
      threads = []
      30.times {
        threads << Thread.new { Thread.current['result'] = RHC::TarGz.contains(subject, 'foo') }
        threads << Thread.new { Thread.current['result'] = RHC::TarGz.contains(subject, 'foo', true) }
      }
      threads.each { |thread| thread.join }
      threads.each { |thread| thread['result'].should be_true }
    }
  end

end
