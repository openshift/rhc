require 'rubygems'
#require 'spec'
require 'webmock/rspec'
#include 'mocha'
require 'rhc/cli'

include WebMock::API

def define_test_command
  Class.new(RHC::Commands::Base) do
    def run
      1      
    end
  end
end

module ClassSpecHelpers

  include Commander::Delegates

  def const_for(obj=nil)
    if obj
      Object.const_set(const_for, obj)
    else
      "#{description}".split(" ").map{|word| word.capitalize}.join.gsub(/[^\w]/, '')
    end
  end
  def new_command_runner *args, &block
    Commander::Runner.instance_variable_set :"@singleton", Commander::Runner.new(args)
    program :name, 'test'
    program :version, '1.2.3'
    program :description, 'something'
    #create_test_command
    yield if block
    Commander::Runner.instance
  end

  def should_run *args
    mock_terminal
    new_command_runner(*args) do
      instance
      subject.should_receive(:new).and_return(instance)
    end.run!
    @output.string
  end

  def mock_terminal
    @input = StringIO.new
    @output = StringIO.new
    $terminal = HighLine.new @input, @output
  end
end

module ExitCodeMatchers
  Spec::Matchers.define :exit_with_code do |code|
    actual = nil
    match do |block|
      begin
        block.call
      rescue SystemExit => e
        actual = e.status
      end
      actual and actual == code
    end
    failure_message_for_should do |block|
      "expected block to call exit(#{code}) but exit" +
        (actual.nil? ? " not called" : "(#{actual}) was called")
    end
    failure_message_for_should_not do |block|
      "expected block not to call exit(#{code})"
    end
    description do
      "expect block to call exit(#{code})"
    end    
  end  
end

Spec::Runner.configure do |config|
  config.include(ExitCodeMatchers)
end


Spec::Runner.configure do |c|
  c.include ClassSpecHelpers
end
