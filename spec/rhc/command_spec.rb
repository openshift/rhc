require 'spec_helper'
require 'rhc/commands/base'
require 'rhc/exceptions'

describe RHC::Commands::Base do
  describe '#object_name' do
    subject { described_class }
    its(:object_name) { should == 'base' }

    context 'when the class is at the root' do
      subject do
        Kernel.module_eval do 
          class StaticRootClass < RHC::Commands::Base; def run; 1; end; end
        end
        StaticRootClass
      end
      its(:object_name) { should == 'static-root-class' }
    end
    context 'when the class is nested in a module' do
      subject do 
        Kernel.module_eval do 
          module Nested; class StaticRootClass < RHC::Commands::Base; def run; 1; end; end; end
        end
        Nested::StaticRootClass
      end
      its(:object_name) { should == 'static-root-class' }
    end
  end

  describe '#inherited' do

    let(:instance) { subject.new }
    let(:commands) { RHC::Commands.send(:commands) }

    context 'when dynamically instantiating without an object name' do
      subject { const_for(Class.new(RHC::Commands::Base) { def run; 1; end }) }

      it("should raise") { expect { subject }.to raise_exception( RHC::Commands::Base::InvalidCommand, /object_name/i ) }
    end

    context 'when dynamically instantiating with object_name' do
      subject { const_for(Class.new(RHC::Commands::Base) { object_name :test; def run(args, options); 1; end }) }

      it("should register itself") { expect { subject }.to change(commands, :length).by(1) }
      it("should have an object name") { subject.object_name.should == 'test' }
      it("should run with wizard") do
        FakeFS.activate!

        wizard_run = false
        RHC::Wizard.stub!(:new) do |config|
          RHC::Wizard.unstub!(:new)
          w = RHC::Wizard.new(config)
          w.stub!(:run) { wizard_run = true }
          w
        end

        expects_running('test').should call(:run).on(instance).with(no_args)
        wizard_run.should be_true

        FakeFS::FileSystem.clear
        FakeFS.deactivate!
      end
    end

    context 'when statically defined' do
      subject do 
        Kernel.module_eval do 
          module Nested
            class Static < RHC::Commands::Base
              suppress_wizard
              def run(args, options); 1; end
            end
          end
        end
        Nested::Static
      end

      it("should register itself") { expect { subject }.to change(commands, :length).by(1) }
      it("should have an object name of the class") { subject.object_name.should == 'static' }
      it("invokes the right method") { expects_running('static').should call(:run).on(instance).with(no_args) }
    end

    context 'when statically defined with no default method' do
      subject do
        Kernel.module_eval do
          class Static < RHC::Commands::Base
            suppress_wizard

            def test; 1; end

            argument :testarg, "Test arg", ["--testarg testarg"]
            summary "Test command execute"
            alias_action :exe, :deprecated => true
            def execute(testarg); 1; end

            argument :args, "Test arg list", [], :arg_type => :list
            summary "Test command execute-list"
            def execute_list(args); 1; end

            def raise_error
              raise StandardError.new("test exception")
            end
            def raise_exception
              raise Exception.new("test exception")
            end
          end
        end
        Static
      end

      it("should register itself") { expect { subject }.to change(commands, :length).by(5) }
      it("should have an object name of the class") { subject.object_name.should == 'static' }

      context 'and when test is called' do
        it { expects_running('static', 'test').should call(:test).on(instance).with(no_args) }
      end
      context 'and when execute is called with argument' do
        it { expects_running('static', 'execute', 'simplearg').should call(:execute).on(instance).with('simplearg') }
      end
      context 'and when execute is called with argument switch' do
        it { expects_running('static', 'execute', '--testarg', 'switcharg').should call(:execute).on(instance).with('switcharg') }
      end
      context 'and when execute is called with same argument and switch' do
        it { expects_running('statis', 'execute', 'duparg', '--testarg', 'duparg2').should exit_with_code(1) }
      end

      context 'and when execute is called with too many arguments' do
        it { expects_running('static', 'execute', 'arg1', 'arg2').should exit_with_code(1) }
      end

      context 'and when execute is called with a missing argument' do
        it { expects_running('static', 'execute').should exit_with_code(1) }
      end

      context 'and when execute_list is called' do
        it { expects_running('static', 'execute-list', '--trace').should call(:execute_list).on(instance).with([]) }
        it { expects_running('static', 'execute-list', '1', '2', '3').should call(:execute_list).on(instance).with(['1', '2', '3']) }
      end

      context 'and when an error is raised in a call' do
        it { expects_running('static', 'raise-error').should raise_error(StandardError, "test exception") }
      end

      context 'and when an exception is raised in a call' do
        it { expects_running('static', 'raise-exception').should raise_error(Exception, "test exception") }
      end

      context 'and when an exception is raised in a call with --trace option' do
        it { expects_running('static', 'raise-exception', "--trace").should raise_error(Exception, "test exception") }
      end

      context 'and when deprecated alias is called' do
        it do
          expects_running('static', 'exe', "arg").should call(:execute).on(instance).with('arg')
          $stderr.seek(0)
          # some systems might redirect warnings to stderr
          output = "#{$stderr.read} #{$terminal.read}"
          output.should match("Warning: This command is deprecated. Please use 'rhc static execute' instead.")
        end
      end

      context 'and when deprecated alias is called with DISABLE_DEPRECATED env var' do
        before { ENV['DISABLE_DEPRECATED'] = '1' }
        after { ENV['DISABLE_DEPRECATED'] = nil }
        it { expects_running('static', 'exe', 'arg', '--trace').should raise_error(RHC::DeprecatedError) }
      end
    end
  end

  describe "rest_client" do
    before do
      FakeFS.activate!
      RHC::Rest::Client.stub!(:new) { |openshift_rest_node, username, password, debug| @username = username; @password = password; true}
    end

    it "should ask for username" do
      $terminal.write_line("testuser@foo.bar")
      $terminal.write_line("password")
      subject.send(:rest_client).should be_true
      @username.should == "testuser@foo.bar"
      subject.send(:config)["default_rhlogin"].should == @username
      @password.should == "password"
    end

    after do
      FakeFS::FileSystem.clear
      FakeFS.deactivate!
    end
  end

end
