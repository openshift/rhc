require 'spec_helper'
require 'rhc/commands/base'

describe RHC::Commands::Base do

  describe '#inherited' do
    before { new_command_runner }

    let(:instance) { i = subject.new; i.should_receive(:run).and_return(1); i }

    context 'when dynamically instantiating without an object name' do
      subject { const_for(Class.new(RHC::Commands::Base) { def run; 1; end }) }
      
      it("should raise") { expect { subject }.to raise_exception( RHC::Commands::Base::InvalidCommand, /object_name/i ) }
    end

    context 'when dynamically instantiating with object_name' do
      subject { const_for(Class.new(RHC::Commands::Base) { object_name :test; def run(args, options); 1; end }) }
      
      it("should register itself") { expect { subject }.to change(commands, :length).by(1) }
      it("should have an object name") { subject.object_name.should == 'test' }
      it { should_run 'test' }
    end

    context 'when statically defined' do
      subject do 
        Kernel.module_eval do 
          class Static < RHC::Commands::Base
            def run(args, options); 1; end
          end
        end
        Static
      end
      
      it("should register itself") { expect { subject }.to change(commands, :length).by(1) }
      it("should have an object name of the class") { subject.object_name.should == 'static' }
      it { should_run 'static' }
    end
  end
end
