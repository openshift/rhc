require 'spec_helper'
require 'rhc/commands/base'
require 'rhc/exceptions'

describe RHC::Commands::Base do
  context 'when statically defined with context' do
    subject do
      Kernel.module_eval do
        class Static < RHC::Commands::Base
          suppress_wizard

          def one_context
            1
          end

          def nil_context
            nil
          end

          option ["--context-opt opt1"], "Test context option", :context => :one_context
          summary "Test command execute with one_context"
          def execute_with_one_context; return options.context_opt; end

          option ["--context-opt opt1"], "Test context option", :context => :nil_context, :required => true
          summary "Test command nil_context"
          def execute_with_nil_context; return options.context_opt; end
        end
      end
      Static
    end

    let(:instance) { subject.new }

    context 'and when execute_with_one_context is called' do
      it { expects_running('static', 'execute-with-one-context').should call(:one_context).on(instance).with(no_args) }
      it { expects_running('static', 'execute-with-one-context').should exit_with_code(1)  }
      it { expects_running('static', 'execute-with-one-context', '--context-opt', 'opt').should call(:execute_with_one_context).on(instance).with(no_args) }
      it { expects_running('static', 'execute-with-one-context', '--context-opt', 'opt').should exit_with_code('opt')  }
    end

    context 'and when execute_with_nil_context is called' do
      it { expects_running('static', 'execute-with-nil-context').should call(:nil_context).on(instance).with(no_args) }
      it { expects_running('static', 'execute-with-nil-context', '--trace').should raise_error(ArgumentError)  }
      it { expects_running('static', 'execute-with-nil-context', '--context-opt', 'opt', '--trace').should call(:execute_with_nil_context).on(instance).with(no_args) }
      it { expects_running('static', 'execute-with-nil-context', '--context-opt', 'opt', '--trace').should exit_with_code('opt')  }
    end
  end
end



