#require 'rubygems'
#require 'spec'
require 'webmock/rspec'

begin
  require 'simplecov'
  SimpleCov.start do
    add_filter 'lib/vendor/'
    add_filter 'lib/rhc-rest.rb'
    add_filter 'lib/rhc-common.rb'
    add_filter 'lib/helpers.rb'
    add_filter 'lib/rhc-rest/' #temporary
    add_filter 'lib/rhc/wizard.rb' #temporary
    add_filter 'lib/rhc/config.rb' #temporary
  end

  original_stderr = $stderr
  at_exit do
    begin
      SimpleCov.result.format!
      if SimpleCov.result.covered_percent < 100
        original_stderr.puts "Coverage not 100%, build failed."
        exit 1
      end
    rescue
      puts "No coverage check, older Ruby"
    end
  end
rescue
end

#include 'mocha'
require 'rhc/cli'

include WebMock::API

module Commander::UI
  alias :enable_paging_old :enable_paging
  def enable_paging
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

  #
  # 
  #
  def expects_running *args
    mock_terminal
    r = new_command_runner args do
      instance #ensure instance is created before subject :new is mocked
      subject.should_receive(:new).any_number_of_times.and_return(instance)
      RHC::Commands.to_commander 
    end
    lambda { r.run!; @output }
  end

  def mock_terminal
    @input = StringIO.new
    @output = StringIO.new
    $stderr = (@error = StringIO.new)
    $terminal = HighLine.new @input, @output
  end

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
end

module ExitCodeMatchers
  Spec::Matchers.define :exit_with_code do |code|
    actual = nil
    match do |block|
      begin
        block.call
      rescue SystemExit => e
        actual = e.status
      else
        actual = 0
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

module CommanderInvocationMatchers
  Spec::Matchers.define :call do |method|
    chain :on do |object|
      @object = object
    end
    chain :with do |args|
      @args = args
    end

    match do |block|
      e = @object.should_receive(method)
      e.with(@args) if @args
      begin
        block.call
        true
      rescue SystemExit => e
        false
      end
    end
    description do
      "expect block to invoke '#{method}' on #{@object} with #{@args}"
    end    
  end  
end

Spec::Runner.configure do |config|
  config.include(ExitCodeMatchers)
  config.include(CommanderInvocationMatchers)
  config.include(ClassSpecHelpers)
end
