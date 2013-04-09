require 'spec_helper'
require 'rhc/wizard'

describe RHC::CLI do

  shared_examples_for 'a global help page' do
    let(:arguments) { @arguments or raise "no arguments" }
    it('should contain the program description') { run_output.should =~ /Command line interface for OpenShift/ }
    it('should describe getting started') { run_output.should =~ /Getting started:/ }
    it('should describe basic command') { run_output.should =~ /Working with apps:/ }
    it('should mention the help command') { run_output.should =~ /See 'rhc help <command>'/ }
    it('should mention the help options command') { run_output.should =~ /rhc help options/ }
  end

  shared_examples_for 'a first run wizard' do
    let(:arguments) { @arguments or raise "no arguments" }
    let!(:wizard){ RHC::Wizard.new }
    before{ RHC::Wizard.should_receive(:new).and_return(wizard) }
    it('should create and run a new wizard') { expect{ run }.to call(:run).on(wizard) }
  end

  shared_examples_for 'a help page' do
    let(:arguments) { @arguments or raise "no arguments" }
    it('should contain the program description') { run_output.should =~ /Command line interface for OpenShift/ }
    it('should contain the global options') { run_output.should =~ /Global Options/ }
    it('should provide a --config switch') { run_output.should =~ /\-\-config FILE/ }
  end

  shared_examples_for 'a list of all commands' do
    let(:arguments) { @arguments or raise "no arguments" }
    it('should contain a message') { run_output.should =~ /Showing all commands/ }
    it('should contain command help') { run_output.should =~ /Create an application./ }
    it('should contain aliases') { run_output.should =~ /\(also/ }
  end

  shared_examples_for 'a list of commands' do
    let(:arguments) { @arguments or raise "no arguments" }
    it('should contain a message') { run_output.should =~ /Showing commands matching '/ }
    it('should contain command help') { run_output.should =~ /Create an application./ }
    it('should contain aliases') { run_output.should =~ /\(also/ }
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

  before{ base_config }

  describe "--version" do
    context "by itself" do
      before :each do
        @arguments = ['--version']
      end
      it_should_behave_like 'version output'
    end
  end

  describe '#start' do
    before{ RHC::Wizard.stub(:has_configuration?).and_return(true) }

    context 'with no arguments' do
      before(:each) { @arguments = [] }
      it_should_behave_like 'a global help page'

      context "without a config file" do
        before{ RHC::Wizard.stub(:has_configuration?).and_return(false) }
        it_should_behave_like 'a first run wizard'
      end
    end

    context 'with an ambiguous option' do
      let(:arguments){ ['help', '-s'] }
      it('should describe an ambiguous error'){ run_output.should match("The option -s is ambiguous. You will need to specify the entire option.") }
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

    context 'with help commands' do
      before(:each) { @arguments = ['help', 'commands'] }
      it_should_behave_like 'a list of all commands'
    end

    context 'with help and possible command matches' do
      before(:each) { @arguments = ['help', 'app c'] }
      it_should_behave_like 'a list of commands'
    end

    context 'with help and a single matching command segment' do
      let(:arguments){ ['help', 'app creat'] }
      it("prints the usage for the command"){ run_output.should match('Usage: rhc app-create <') }
      it("prints part of the description for the command"){ run_output.should match('OpenShift runs the components of your') }
      it("prints a local option"){ run_output.should match('--namespace NAME') }
    end

    context 'with --help' do
      before(:each){ @arguments = ['--help'] }
      it_should_behave_like 'a global help page'

      context 'without a config file' do
        before{ RHC::Wizard.stub(:has_configuration?).and_return(false) }
        it_should_behave_like 'a global help page'
      end
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
      $stdin.should_receive(:tty?).once.and_return(true)
      HighLine::SystemExtensions.should_receive(:terminal_size).and_return([5])
      expect { RHC::CLI.set_terminal }.to change($terminal, :wrap_at)
    end
    it('should not update $terminal.page_at') do 
      $stdin.should_receive(:tty?).once.and_return(true)
      $stdout.should_receive(:tty?).once.and_return(true)
      expect { RHC::CLI.set_terminal }.to_not change($terminal, :page_at)
    end
  end

end
