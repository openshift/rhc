require 'spec_helper'
require 'rhc/commands/base'

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
      its(:object_name) { should == 'staticrootclass' }
    end
    context 'when the class is nested in a module' do
      subject do 
        Kernel.module_eval do 
          module Nested; class StaticRootClass < RHC::Commands::Base; def run; 1; end; end; end
        end
        Nested::StaticRootClass
      end
      its(:object_name) { should == 'staticrootclass' }
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
      # it("should run with wizard") do
      #   FakeFS.activate!
      # 
      #   wizard_run = false
      #   RHC::Wizard.stub!(:new) do |config|
      #     RHC::Wizard.unstub!(:new)
      #     w = RHC::Wizard.new(config)
      #     w.stub!(:run) { wizard_run = true }
      #     w
      #   end
      # 
      #   expects_running('test').should call(:run).on(instance).with(no_args)
      #   wizard_run.should be_true
      # 
      #   FakeFS::FileSystem.clear
      #   FakeFS.deactivate!
      # end
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

            argument :testarg, "Test arg", "--testarg testarg"
            summary "Test command execute"
            def execute; 1; end
            def raise_exception
              raise Exception.new("test exception")
            end
          end
        end
        Static
      end

      it("should register itself") { expect { subject }.to change(commands, :length).by(3) }
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

      context 'and when an exception is raised in a call' do
        it { expects_running('static', 'raise_exception').should exit_with_code(128) }
      end

      context 'and when an exception is raised in a call with --trace option' do
        it { expects_running('static', 'raise_exception', "--trace").should raise_error(Exception, "test exception") }
      end
    end
  end
end
