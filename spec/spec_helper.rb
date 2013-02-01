require 'coverage_helper'
require 'webmock/rspec'
require 'fakefs/safe'
require 'rbconfig'

require 'pry' if ENV['PRY']

# Environment reset
ENV['http_proxy'] = nil
ENV['HTTP_PROXY'] = nil

class FakeFS::Mode
  def initialize(mode_s)
    @s = mode_s
  end
  def to_s(*args)
    @s
  end
end
class FakeFS::Stat
  attr_reader :mode
  def initialize(mode_s)
    @mode = FakeFS::Mode.new(mode_s)
  end
end

# chmod isn't implemented in the released fakefs gem
# but is in git.  Once the git version is released we
# should remove this and actively check permissions
class FakeFS::File
  def self.chmod(*args)
    # noop
  end

  def self.stat(path)
    FakeFS::Stat.new(mode(path))
  end

  def self.mode(path)
    @modes && @modes[path] || '664'
  end
  def self.expect_mode(path, mode)
    (@modes ||= {})[path] = mode
  end

  # FakeFS incorrectly assigns this to '/'
  remove_const(:PATH_SEPARATOR) rescue nil
  const_set(:PATH_SEPARATOR, ":")
  const_set(:ALT_SEPARATOR, '') rescue nil

  def self.executable?(path)
    # if the file exists we will assume it is executable
    # for testing purposes
    self.exists?(path)
  end
end

require 'rhc/cli'

include WebMock::API

def stderr
  $stderr.rewind
  # some systems might redirect warnings to stderr
  [$stderr,$terminal].map(&:read).delete_if{|x| x.strip.empty?}.join(' ')
end

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

  def with_constants(constants, base=Object, &block)
    constants.each do |constant, val|
      base.const_set(constant, val)
    end

    block.call
  ensure
    constants.each do |constant, val|
      base.send(:remove_const, constant)
    end
  end

  def new_command_runner *args, &block
    Commander::Runner.instance_variable_set :"@singleton", RHC::CommandRunner.new(args)
    program :name, 'test'
    program :version, '1.2.3'
    program :description, 'something'
    program :help_formatter, RHC::HelpFormatter

    #create_test_command
    yield if block
    Commander::Runner.instance
  end

  #
  # 
  #
  def expects_running(*args, &block)
    mock_terminal
    r = new_command_runner *args do
      instance #ensure instance is created before subject :new is mocked
      subject.should_receive(:new).any_number_of_times.and_return(instance)
      RHC::Commands.to_commander
    end
    lambda { r.run! }
  end
  def command_for(*args)
    mock_terminal
    r = new_command_runner *args do
      instance #ensure instance is created before subject :new is mocked
      subject.should_receive(:new).any_number_of_times.and_return(instance)
      RHC::Commands.to_commander
    end
    command = nil
    RHC::Commands.stub(:execute){ |cmd, method, args| command = cmd; 0 }
    r.run!
    command
  end

  class MockHighLineTerminal < HighLine
    def initialize(input, output)
      super
      @last_read_pos = 0
    end

    ##
    # read
    #
    # seeks to the last read in the IO stream and reads
    # the data from that position so we don't repeat
    # reads or get empty data due to writes moving
    # the caret to the end of the stream
    def read
      @output.seek(@last_read_pos)
      result = @output.read
      @last_read_pos = @output.pos
      result
    end

    ##
    # write_line
    #
    # writes a line of data to the end of the
    # input stream appending a newline so
    # highline knows to stop processing and then
    # resets the caret position to the last read
    def write_line(str)
      reset_pos = @input.pos
      # seek end so we don't overwrite anything
      @input.seek(0, IO::SEEK_END)
      result = @input.write "#{str}\n"
      @input.seek(reset_pos)
      result
    end
    def close_write
      @input.close_write
    end
  end

  def mock_terminal
    @input = StringIO.new
    @output = StringIO.new
    $stderr = (@error = StringIO.new)
    $terminal = MockHighLineTerminal.new @input, @output
  end
  def input_line(s)
    $terminal.write_line s
  end
  def last_output(&block)
    if block_given?
      yield $terminal.read
    else
      $terminal.read
    end
  end

  def capture(&block)
    old_stdout = $stdout
    old_stderr = $stderr
    old_terminal = $terminal
    @input = StringIO.new
    @output = StringIO.new
    $stdout = @output
    $stderr = (@error = StringIO.new)
    $terminal = MockHighLineTerminal.new @input, @output
    yield
    @output.string
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
    $terminal = old_terminal
  end

  def capture_all(&block)
    old_stdout = $stdout
    old_stderr = $stderr
    old_terminal = $terminal
    @input = StringIO.new
    @output = StringIO.new
    $stdout = @output
    $stderr = @output
    $terminal = MockHighLineTerminal.new @input, @output
    yield
    @output.string
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
    $terminal = old_terminal
  end

  def run(input=[])
    #Commander::Runner.instance_variable_set :"@singleton", nil
    mock_terminal
    input.each { |i| $terminal.write_line(i) }
    $terminal.close_write
    #"#{@output.string}\n#{$stderr.string}"
    RHC::CLI.start(arguments)
  end

  def run_output(input=[])
    run(input)
  rescue SystemExit => e
    "#{@output.string}\n#{$stderr.string}#{e}"
  else
    "#{@output.string}\n#{$stderr.string}"
  end

  #
  # usage: stub_request(...).with(&user_agent_header)
  #
  def user_agent_header
    lambda do |request|
      #User-Agent is not sent to mock by httpclient
      #request.headers['User-Agent'] =~ %r{\Arhc/\d+\.\d+.\d+ \(.*?ruby.*?\)}
      true
    end
  end

  def base_config(&block)
    config = RHC::Config.new
    config.stub(:load_config_files)
    defaults = config.instance_variable_get(:@defaults)
    yield config, defaults if block_given?
    RHC::Config.stub(:default).and_return(config)
    RHC::Config.stub(:new).and_return(config)
    config
  end

  def user_config
    user = respond_to?(:username) ? self.username : 'test_user'
    password = respond_to?(:password) ? self.password : 'test pass'
    server = respond_to?(:server) ? self.server : nil

    base_config do |config, defaults|
      defaults.add 'default_rhlogin', user
      defaults.add 'password', password
      defaults.add 'libra_server', server if server
    end.tap do |c|
      opts = c.to_options
      opts[:rhlogin].should == user
      opts[:password].should == password
      opts[:server].should == server if server
    end
  end
end

module ExitCodeMatchers
  Spec::Matchers.define :exit_with_code do |code|
    actual = nil
    match do |block|
      begin
        actual = block.call
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

def mac?
  RbConfig::CONFIG['host_os'] =~ /^darwin/
end

Spec::Runner.configure do |config|
  config.include(ExitCodeMatchers)
  config.include(CommanderInvocationMatchers)
  config.include(ClassSpecHelpers)
end

module TestEnv
  extend ClassSpecHelpers
  class << self
    attr_accessor :instance, :subject
    def instance=(i)
      self.subject = i.class
      @instance = i
    end
  end
end
