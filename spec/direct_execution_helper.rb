require 'open4'
require 'rhc/helpers'

$source_bin_rhc = File.expand_path('bin/rhc')

SimpleCov.minimum_coverage = 0 # No coverage testing for features

#
# RHC_DEBUG=true TEST_INSECURE=1 TEST_USERNAME=test1 TEST_PASSWORD=password \
#  RHC_SERVER=hostname \
#  bundle exec rspec features/*_feature.rb
#

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
    unless server_supports_sessions?
      args << '--password'
      args << ENV['TEST_PASSWORD']
    end
    execute_command(args.unshift(rhc_executable), opts[:with])
  end

  def execute_command(args, stdin="", tty=true)
    stdin = stdin.join("\n") if stdin.is_a? Array
    stdout, stderr =
      if debug?
        [STDOUT, STDERR].map{ |t| RHC::Helpers::StringTee.new(t) } 
      else
        [StringIO.new, StringIO.new]
      end

    args.map!(&:to_s)
    status = Open4.spawn(args, 'stdout' => stdout, 'stderr' => stderr, 'stdin' => stdin, 'quiet' => true)
    stdout, stderr = [stdout, stderr].map(&:string)
    Result.new(args, status, stdout, stderr).tap do |r|
      STDERR.puts "\n[#{example_description}] #{r}" if debug?
    end
  end

  def rhc_executable
    ENV['RHC_TEST_SYSTEM'] ? 'rhc' : $source_bin_rhc
  end

  def client
    @client ||= (@environment && @environment[:client]) || begin
      WebMock.allow_net_connect!
      opts = {:server => ENV['RHC_SERVER']}
      if token = RHC::Auth::TokenStore.new(File.expand_path("~/.openshift")).get(ENV['TEST_USERNAME'], ENV['RHC_SERVER'])
        opts[:token] = token
      else
        opts[:user] = ENV['TEST_USERNAME']
        opts[:password] = ENV['TEST_PASSWORD']
      end
      opts[:verify_mode] = OpenSSL::SSL::VERIFY_NONE if ENV['TEST_INSECURE'] == '1'
      env = RHC::Rest::Client.new(opts)
      @environment[:client] = env if @environment
      env
    end
  end

  def base_client(user, password)
    opts = {:server => ENV['RHC_SERVER']}
    opts[:user] = user
    opts[:password] = password
    opts[:verify_mode] = OpenSSL::SSL::VERIFY_NONE if ENV['TEST_INSECURE'] == '1'
    RHC::Rest::Client.new(opts)
  end

  def no_applications(constraint=nil)
    STDERR.puts "Removing applications that match #{constraint}" if debug?
    apps = client.reset.applications
    apps.each do |app|
      next if constraint && !(app.name =~ constraint)
      STDERR.puts "  removing #{app.name}" if debug?
      app.destroy
    end
  end

  def other_users
    $other_users ||= begin
      (ENV['TEST_OTHER_USERS'] || "other1:a,other2:b,other3:c,other4:d").split(',').map{ |s| s.split(':') }.inject({}) do |h, (u, p)|
        h[u] = base_client(u, p).user
        h
      end
    end
  end

  def no_members(object)
    object.delete_members
    object.members.length.should == 1
  end

  def has_an_application
    STDERR.puts "Creating or reusing an app" if debug?
    apps = client.applications
    apps.first or begin
      domain = has_a_domain
      STDERR.puts "  creating a new application" if debug?
      client.domains.first.add_application("test#{random}", :cartridges => [a_web_cartridge])
    end
  end

  def has_a_domain
    STDERR.puts "Creating or reusing a domain" if debug?
    domain = client.domains.first or begin
      STDERR.puts "  creating a new domain" if debug?
      client.add_domain("test#{random}")
    end
  end

  def setup_args(opts={})
    args = []
    args << 'yes' if (ENV['TEST_INSECURE'] == '1' || false)
    args << ENV['TEST_USERNAME']
    args << ENV['TEST_PASSWORD']
    args << 'yes' if server_supports_sessions?
    args << 'yes' # generate a key, temp dir will never have one
    args << ENV['TEST_USERNAME'] if (client.find_key('default').present? rescue false) # same key name as username
    args << "d#{random}" if (client.domains.empty? rescue true)
    args
  end

  def use_clean_config
    environment
    FileUtils.rm_rf(File.join(@environment[:dir], ".openshift"))
    client.reset
  end

  def standard_config
    environment(:standard) do
      r = rhc :setup, :with => setup_args
      raise "Unable to configure standard config" if r.status != 0
    end
    client.reset
  end

  def debug?
    @debug ||= !!ENV['RHC_DEBUG']
  end

  def random
    @environment[:id]
  end

  def server_supports_sessions?
    @environment && client.supports_sessions?
  end

  private
    def example_description
      if respond_to?(:example) && example
        example.metadata[:full_description]
      else
        self.class.example.metadata[:full_description]
      end
    end

    def environment(id=nil)
      unless @environment
        is_new = false
        e = Environments.get(id){ is_new = true}
        update_env(e)

        dir = Dir.mktmpdir('rhc_features_test')
        at_exit{ FileUtils.rm_rf(dir) }
        Dir.chdir(dir)

        @client = e[:client]
        @environment = e
        yield if block_given? && is_new
      end
      @environment
    end

    def update_env(config)
      ENV['HOME'] = config[:dir]
      ENV['RHC_SERVER'] ||= 'openshift.redhat.com'
      if ENV['TEST_RANDOM_USER']
        {
          'TEST_USERNAME' => "test_user_#{config[:id]}",
          'TEST_PASSWORD' => "password",
        }.each_pair{ |k,v| ENV[k] = v }
      else
        ENV['TEST_USERNAME'] or raise "No TEST_USERNAME set"
        ENV['TEST_PASSWORD'] or raise "No TEST_PASSWORD set"
      end
      ENV['GIT_SSH'] = config[:ssh_exec]
    end
end

module Environments
  def self.get(id, &block)
    (@environments ||= {})[id] ||= begin
      dir = Dir.mktmpdir('rhc_features')
      at_exit{ FileUtils.rm_rf(dir) }
      id = Random.rand(1000000)
      ssh_exec = File.join(dir, "ssh_exec")
      IO.write(ssh_exec, "#!/bin/sh\nssh -o StrictHostKeyChecking=no -i #{dir}/.ssh/id_rsa \"$@\"")
      FileUtils.chmod("u+x", ssh_exec)
      yield if block_given?
      {:dir => dir, :id => id, :ssh_exec => ssh_exec}
    end
  end
end

RSpec.configure do |config|
  config.include(RhcExecutionHelper)
  config.extend(RhcExecutionHelper)
end