require 'spec_helper'

describe RHC::CLI do

  shared_examples_for 'a help page' do
    let(:arguments) { @arguments or raise "no arguments" }
    it('should contain the program description') { run_output.should =~ /Command line interface for OpenShift/ }
    it('should contain the global options') { run_output.should =~ /Global Options/ }
    it('should provide a --config switch') { run_output.should =~ /\-\-config FILE/ }
  end

  describe '#start' do
    context 'with no arguments' do
      let(:arguments) { [] }
      it { expect { run }.should exit_with_code(1) }
      it('should provide a message about --help') { run_output.should =~ /\-\-help/ }
    end

    context 'with --help' do
      before(:each){ @arguments = ['--help'] }
      it_should_behave_like 'a help page'
    end
    
    context 'with -h' do
      before(:each){ @arguments = ['-h'] }
      it_should_behave_like 'a help page'
    end

    context 'with help' do
      before(:each){ @arguments = ['help'] }
      it_should_behave_like 'a help page'
    end
  end

  describe '#set_terminal' do
    before(:each) { mock_terminal }
    it('should update $terminal.wrap_at') { expect { RHC::CLI.set_terminal }.to change($terminal, :wrap_at) }
  end

end
