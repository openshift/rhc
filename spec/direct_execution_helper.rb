require 'open4'
require 'rhc/helpers'

$source_bin_rhc = File.expand_path('bin/rhc')

SimpleCov.minimum_coverage = 0 # No coverage testing for features

module RhcExecutionHelper
  class Result < Struct.new(:args, :status, :stdout, :stderr)
    def to_s
      "Ran #{args.inspect} and got #{status}\n#{'-'*50}\n#{stdout}#{'-'*50}\n#{stderr}"
    end
    def successful?
      status == 0
    end
  end

  def when_running(*args)
    subject{ rhc *args }
    let(:output){ subject.stdout }
    let(:status){ subject.status }
    before{ standard_config }
  end

  def a_web_cartridge
    'php-5.3'
  end

  def rhc(*args)
    opts = args.pop if args.last.is_a? Hash
    opts ||= {}
    unless server_info[:supports_tokens]
      args.unshift ENV['RHC_PASSWORD']
      args.unshift '--password'
    end
    execute_command(args.unshift(rhc_executable), opts[:with])
  end

  def execute_command(args, stdin="", tty=true)
    stdin = stdin.join("\n") if stdin.is_a? Array
    stdout, stderr = 
      if ENV['RHC_DEBUG']
        [STDOUT, STDERR].map{ |t| RHC::Helpers::StringTee.new(t) } 
      else
        [StringIO.new, StringIO.new]
      end

    #[stdout,stdin].each{ |io| io.stub(:tty?).and_return(true) if io }
    args.map!(&:to_s)
    status = Open4.spawn(args, 'stdout' => stdout, 'stderr' => stderr, 'stdin' => stdin, 'quiet' => true)
    stdout, stderr = [stdout, stderr].map(&:string)
    Result.new(args, status, stdout, stderr).tap do |r|
      STDERR.puts r if ENV['RHC_DEBUG']
    end
  end

  def rhc_executable
    ENV['RHC_TEST_SYSTEM'] ? 'rhc' : $source_bin_rhc
  end

  def server_info
    $server_info ||= {
      :insecure => false,             # if an https get to broker/rest/api raises a cert error
      :supports_tokens => true,       # if server has API link for 'LIST_AUTHORIZATIONS'
      :needs_unique_ssh_key => true,  # if server has key named default and creating new key
      :needs_domain_created => false, # if the server has a domain already
    }    
  end

  def client
    @client ||= begin
      WebMock.allow_net_connect!
      opts = {:server => ENV['RHC_SERVER']}
      if token = RHC::Auth::TokenStore.new(File.expand_path("~/.openshift")).get(ENV['RHC_USERNAME'], ENV['RHC_SERVER'])
        opts[:token] = token
      else
        opts[:user] = ENV['RHC_USERNAME']
        opts[:password] = ENV['RHC_PASSWORD']
      end
      RHC::Rest::Client.new(opts)
    end
  end

  def no_applications(constraint=nil)
    STDERR.puts "Removing applications that match #{constraint}" if ENV['RHC_DEBUG']
    apps = client.domains.map(&:applications).flatten
    apps.each do |app|
      next if constraint && !(app.name =~ constraint)
      STDERR.puts "  removing #{app.name}" if ENV['RHC_DEBUG']
      app.destroy
    end
  end

  def has_an_application
    STDERR.puts "Creating or reusing an app" if ENV['RHC_DEBUG']
    apps = client.domains.map(&:applications).flatten
    apps.first or begin
      domain = client.domains or begin
        STDERR.puts "  creating a new domain" if ENV['RHC_DEBUG']
        client.add_domain("test#{Random.random(100000)}")
      end
      STDERR.puts "  creating a new application" if ENV['RHC_DEBUG']
      client.domains.first.add_application(:name => "test#{Random.random(100000)}", :cartridges => [a_web_cartridge])
    end
  end

  def setup_args(opts={})
    args = []
    args << 'yes' if server_info[:insecure]
    args << ENV['RHC_USERNAME']
    args << ENV['RHC_PASSWORD']
    args << 'yes' if server_info[:supports_tokens]
    args << "d#{random}" if server_info[:needs_domain_created]
    args << 'yes' # generate a key, temp dir will never have one
    args << ENV['RHC_USERNAME'] # same key name as username
  end

  def use_clean_config
    set_environment([Dir.mktmpdir('rhc_features'), Random.rand(100000)])
    Dir.chdir(Dir.mktmpdir)
    server_info
  end

  def standard_config
    $standard_config ||= begin
      [Dir.mktmpdir('rhc_features'), Random.rand(100000), false]      
    end
    set_environment($standard_config)
    server_info
    Dir.chdir(Dir.mktmpdir)    
    if $standard_config.last == false
      r = rhc :setup, :with => setup_args
      raise "Unable to configure standard config" if r.status != 0
      $standard_config[-1] = true
    end
  end

  private
    def set_environment(config)
      dir, random = config
      ENV['HOME'] = dir
      ENV['RHC_SERVER'] ||= 'openshift.redhat.com'
      if ENV['RHC_TEST_RANDOM']
        ENV.merge(
          'RHC_USERNAME' => "test_user_#{random}",
          'RHC_PASSWORD' => "password",
        )
      else     
        ENV['RHC_USERNAME'] or raise "No RHC_USERNAME set"
        ENV['RHC_PASSWORD'] or raise "No RHC_PASSWORD set"
      end
    end
end

RSpec.configure do |config|
  config.include(RhcExecutionHelper)
  config.extend(RhcExecutionHelper)
end