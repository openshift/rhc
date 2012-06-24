require 'spec_helper'

describe RHC::CLI do

  describe '#start' do
    context 'with no arguments' do
      let(:arguments) { [] }
      it { expect { run }.should exit_with_code(1) }
      it('should provide a message about --help') { run_output.should =~ /\-\-help/ }
    end

    context 'with --help' do
      let(:arguments) { ['--help'] }
      it { expect { run }.should exit_with_code(0) }
      it('should contain the program description') { run_output.should =~ /Command line interface for OpenShift/ }
    end
  end

  describe '#set_terminal' do
    before(:each) { mock_terminal }
    it('should update $terminal.wrap_at') { expect { RHC::CLI.set_terminal }.to change($terminal, :wrap_at) }
  end

end
