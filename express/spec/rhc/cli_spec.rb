require 'spec_helper'

describe RHC::CLI do

  describe '#start' do
    def run
      #Commander::Runner.instance_variable_set :"@singleton", nil
      mock_terminal
      RHC::CLI.start(arguments)
      "#{@output.string}\n#{$stderr.string}"
    end
    def run_output
      run
    rescue SystemExit => e
      "#{@output.string}\n#{$stderr.string}#{e}"
    else
      "#{@output.string}\n#{$stderr.string}"
    end

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

    context 'with "status"' do
      let(:arguments) { ['status'] }
      it { expect { run }.should exit_with_code(0) }
      it('should contain a stub message') { run_output.should =~ /server status/ }
    end

    context 'with "app"' do
      let(:arguments) { ['app'] }
      it { expect { run }.should exit_with_code(1) }
      it('should contain a stub message') { run_output.should =~ /invalid command/ }
    end

  end

  describe '#set_terminal' do
    before(:each) { mock_terminal }
    it('should update $terminal.wrap_at') { expect { RHC::CLI.set_terminal }.to change($terminal, :wrap_at) }
  end

end
