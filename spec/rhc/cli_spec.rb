require 'spec_helper'

describe RHC::CLI do

  shared_examples_for 'a global help page' do
    let(:arguments) { @arguments or raise "no arguments" }
    it('should contain the program description') { run_output.should =~ /Command line interface for OpenShift/ }
    it('should describe getting started') { run_output.should =~ /Getting started:/ }
    it('should describe basic command') { run_output.should =~ /Working with apps:/ }
    it('should mention the help command') { run_output.should =~ /See 'rhc help <command>'/ }
    it('should mention the help options command') { run_output.should =~ /rhc help options/ }
  end

  shared_examples_for 'a help page' do
    let(:arguments) { @arguments or raise "no arguments" }
    it('should contain the program description') { run_output.should =~ /Command line interface for OpenShift/ }
    it('should contain the global options') { run_output.should =~ /Global Options/ }
    it('should provide a --config switch') { run_output.should =~ /\-\-config FILE/ }
  end

  shared_examples_for 'a command-line options help page' do
    let(:arguments) { @arguments or raise "no arguments" }
    it('should contain an introduction') { run_output.should =~ /The following options can be passed to any/ }
    it('should reference the configuration') { run_output.should match(".openshift/express.conf") }
    it('should describe the --config switch') { run_output.should =~ /\-\-config FILE/ }
    it('should describe the --ssl-version switch') { run_output.should =~ /\-\-ssl\-version VERSION/ }
  end

  shared_examples_for 'an invalid command' do
    let(:arguments) { @arguments }
    it('should contain the invalid command message') { run_output.should =~ /is not recognized/ }
    it('should contain the arguments') { run_output.should include(@arguments[0]) }
    it('should reference --help') { run_output.should =~ / help\b/ }
  end
  
  shared_examples_for 'version output' do
    let(:arguments) { @arguments }
    it 'should contain version output' do
      run_output.should =~ /rhc \d+\.\d+(:?\.d+)?/
    end
  end
  
  describe "--version" do
    context "by itself" do
      before :each do
        @arguments = ['--version']
      end
      it_should_behave_like 'version output'
    end
    
    context 'given as "-v"' do
      before :each do
        @arguments = ['-v']
      end
      it_should_behave_like 'version output'
    end
  end

  describe '#start' do
    context 'with no arguments' do
      before(:each) { @arguments = [] }
      it_should_behave_like 'a global help page'
    end

    context 'with an invalid command' do
      before(:each) { @arguments = ['invalidcommand'] }
      it_should_behave_like 'an invalid command'
    end

    context 'with --help and invalid command' do
      before(:each) { @arguments = ['invalidcommand', '--help'] }
      it_should_behave_like 'an invalid command'
    end

    context 'with help and invalid command' do
      before(:each) { @arguments = ['help', 'invalidcommand'] }
      it_should_behave_like 'an invalid command'
    end

    context 'with --help' do
      before(:each){ @arguments = ['--help'] }
      it_should_behave_like 'a global help page'
    end

    context 'with -h' do
      before(:each){ @arguments = ['-h'] }
      it_should_behave_like 'a global help page'
    end

    context 'with help' do
      before(:each){ @arguments = ['help'] }
      it_should_behave_like 'a global help page'
    end

    context 'with help options' do
      before(:each){ @arguments = ['help', 'options'] }
      it_should_behave_like 'a command-line options help page'
    end
  end

  describe '#set_terminal' do
    before(:each) { mock_terminal }
    it('should update $terminal.wrap_at') do 
      $stdin.should_receive(:tty?).twice.and_return(true)
      HighLine::SystemExtensions.should_receive(:terminal_size).and_return([5])
      expect { RHC::CLI.set_terminal }.to change($terminal, :wrap_at)
    end
    it('should update $terminal.page_at') do 
      $stdin.should_receive(:tty?).twice.and_return(true)
      expect { RHC::CLI.set_terminal }.to change($terminal, :page_at)
    end
  end

end
