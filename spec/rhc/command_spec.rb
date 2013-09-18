require 'spec_helper'
require 'rhc/commands/base'
require 'rhc/exceptions'
require 'rest_spec_helper'

describe RHC::Commands::Base do

  let!(:config){ base_config }

  before{ c = RHC::Commands.instance_variable_get(:@commands); @saved_commands = c && c.dup || nil }
  after do
    (Kernel.send(:remove_const, subject) if subject.is_a?(Class)) rescue nil
    RHC::Commands.instance_variable_set(:@commands, @saved_commands)
  end

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
        FakeFS do
          wizard_run = false
          RHC::Wizard.stub(:new) do |config|
            RHC::Wizard.unstub!(:new)
            w = RHC::Wizard.new(config)
            w.stub(:run) { wizard_run = true }
            w
          end

          expects_running('test').should call(:run).on(instance).with(no_args)
          wizard_run.should be_false

          stderr.should match("You have not yet configured the OpenShift client tools")
        end
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

    context 'when a command calls exit' do
      subject do
        Kernel.module_eval do
          class Failing < RHC::Commands::Base
            def run
              exit 2
            end
          end
        end
        Failing
      end

      it("invokes the right method") { expects_running('failing').should call(:run).on(instance).with(no_args) }
      it{ expects_running('failing').should exit_with_code(2) }
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

            argument :args, "Test arg list", ['--tests ARG'], :arg_type => :list
            summary "Test command execute-list"
            def execute_list(args); 1; end

            argument :arg1, "Test arg", ['--test'], :optional => true
            argument :arg2, "Test arg list", ['--test2'], :arg_type => :list, :optional => true
            argument :arg3, "Test arg list", ['--test3'], :arg_type => :list, :optional => true
            summary "Test command execute-vararg"
            def execute_vararg(arg1, arg2, arg3); 1; end

            RHC::Helpers.global_option '--test-context', 'Test', :context => :context_var
            def execute_implicit
            end

            argument :testarg, "Test arg", ["--testarg testarg"], :context => :context_var
            summary "Test command execute"
            def execute_context_arg(testarg); 1; end

            def raise_error
              raise StandardError.new("test exception")
            end
            def raise_exception
              raise Exception.new("test exception")
            end

            protected
              def context_var
                "contextual"
              end
          end
        end
        Static
      end

      it("should register itself") { expect { subject }.to change(commands, :length).by(8) }
      it("should have an object name of the class") { subject.object_name.should == 'static' }

      context 'and when test is called' do
        it { expects_running('static-test').should call(:test).on(instance).with(no_args) }
      end

      context 'and when execute is called with argument' do
        it { expects_running('static-execute', 'simplearg').should call(:execute).on(instance).with('simplearg') }
      end
      context 'and when execute is called with argument switch' do
        it { expects_running('static-execute', '--testarg', 'switcharg').should call(:execute).on(instance).with('switcharg') }
      end
      context 'and when execute is called with same argument and switch' do
        it { expects_running('statis-execute', 'duparg', '--testarg', 'duparg2').should exit_with_code(1) }
      end

      context 'and when the provided option is ambiguous' do
        it { expects_running('static-execute', '-t', '--trace').should raise_error(OptionParser::AmbiguousOption) }
      end

      context 'and when execute is called with too many arguments' do
        it { expects_running('static-execute', 'arg1', 'arg2').should exit_with_code(1) }
      end

      context 'and when execute is called with a missing argument' do
        it { expects_running('static-execute').should exit_with_code(1) }
      end

      context 'and when execute_list is called' do
        it { expects_running('static-execute-list', '--trace').should call(:execute_list).on(instance).with([]) }
        it { expects_running('static-execute-list', '1', '2', '3').should call(:execute_list).on(instance).with(['1', '2', '3']) }
        it { expects_running('static-execute-list', '1', '2', '3').should call(:execute_list).on(instance).with(['1', '2', '3']) }
        it('should make the option an array') { expects_running('static-execute-list', '--tests', '1').should call(:execute_list).on(instance).with(['1']) }
        it('should make the option available') { command_for('static-execute-list', '1', '2', '3').send(:options).tests.should == ['1','2','3'] }
      end

      context 'and when execute_vararg is called' do
        it{ expects_running('static-execute-vararg').should call(:execute_vararg).on(instance).with(nil, nil, nil) }
        it{ expects_running('static-execute-vararg', '1', '2', '3').should call(:execute_vararg).on(instance).with('1', ['2', '3'], []) }
        it("handles a list separator"){ expects_running('static-execute-vararg', '1', '2', '--', '3').should call(:execute_vararg).on(instance).with('1', ['2'], ['3']) }
        it{ command_for('static-execute-vararg', '1', '2', '--', '3').send(:options).test.should == '1' }
        it{ command_for('static-execute-vararg', '1', '2', '--', '3').send(:options).test2.should == ['2'] }
        it{ command_for('static-execute-vararg', '1', '2', '--', '3').send(:options).test3.should == ['3'] }
      end
      context 'and when execute is called with a contextual global option' do
        it("calls the helper") { command_for('static', 'execute-implicit').send(:options).test_context.should == 'contextual' }
      end

      context 'and when execute-context-arg is called with a contextual argument' do
        it("calls the helper") { command_for('static', 'execute-context-arg').send(:options).test_context.should == 'contextual' }
        it("takes the argument") { command_for('static', 'execute-context-arg', 'arg1').send(:options).testarg.should == 'arg1' }
      end

      context 'and when an error is raised in a call' do
        it { expects_running('static-raise-error').should raise_error(StandardError, "test exception") }
      end

      context 'and when an exception is raised in a call' do
        it { expects_running('static-raise-exception').should raise_error(Exception, "test exception") }
      end

      context 'and when an exception is raised in a call with --trace option' do
        it { expects_running('static-raise-exception', "--trace").should raise_error(Exception, "test exception") }
      end

      context 'and when deprecated alias is called' do
        it("prints a warning") do
          expects_running('static', 'exe', "arg").should call(:execute).on(instance).with('arg')
          stderr.should match("Warning: This command is deprecated. Please use 'rhc static-execute' instead.")
        end
      end

      context 'and when deprecated alias is called with DISABLE_DEPRECATED env var' do
        before { ENV['DISABLE_DEPRECATED'] = '1' }
        after { ENV['DISABLE_DEPRECATED'] = nil }
        it("raises an error") { expects_running('static', 'exe', 'arg', '--trace').should raise_error(RHC::DeprecatedError) }
      end
    end
  end

  describe "find_app" do
    let(:instance){ subject }
    let(:rest_client){ subject.send(:rest_client) }
    let(:options){ subject.send(:options) }
    def expects_method(*args)
      expect{ subject.send(:find_app, *args) }
    end

    it("should raise without params"){ expects_method(nil).to raise_error(ArgumentError, /You must specify an application with -a/) }

    context "when looking for an app" do
      before{ subject.stub(:namespace_context).and_return('domain_s') }
      before{ subject.stub(:app_context).and_return('app_s') }
      it("should handle direct")   { expects_method('app').to call(:find_application).on(rest_client).with('domain_s', 'app') }
      it("should handle namespace param"){ options[:namespace] = 'domain_o'; expects_method('app').to call(:find_application).on(rest_client).with('domain_o', 'app') }
      it("should ignore app param"){ options[:app] = 'app_o'; expects_method('app').to call(:find_application).on(rest_client).with('domain_s', 'app') }
      it("should accept app param"){ options[:app] = 'app_o'; expects_method(nil).to call(:find_application).on(rest_client).with('domain_s', 'app_o') }
      it("should split app param") { options[:app] = 'domain_o/app_o'; expects_method(nil).to call(:find_application).on(rest_client).with('domain_o', 'app_o') }
      it("should accept split app"){ expects_method('domain/app').to call(:find_application).on(rest_client).with('domain', 'app') }
    end
  end

  describe "find_domain_or_app" do
    let(:instance){ subject }
    let(:rest_client){ subject.send(:rest_client) }
    let(:options){ subject.send(:options) }
    before{ subject.stub(:namespace_context).and_return('domain_s') }
    def expects_method(*args)
      expect{ subject.send(:find_app_or_domain, *args) }
    end

    it("should not infer domain")             { expects_method(nil).to raise_error(ArgumentError, /You must specify a domain with -n, or an application with -a/) }
    it("should assume domain without options"){ expects_method('domain').to call(:find_domain).on(rest_client).with('domain') }
    it("should let arg assume domain")        { options[:namespace] = 'domain_o'; expects_method('domain').to call(:find_domain).on(rest_client).with('domain') }
    it("should assume domain with -n")        { options[:namespace] = 'domain_o'; expects_method(nil).to call(:find_domain).on(rest_client).with('domain_o') }
    it("should let arg override -a")          { options[:app] = 'app_o'; expects_method('domain').to call(:find_domain).on(rest_client).with('domain') }
    it("should infer -n when -a is available"){ options[:app] = 'app_o'; expects_method(nil).to call(:find_application).on(rest_client).with('domain_s', 'app_o') }
    it("should split -a param")               { options[:app] = 'domain_o/app_o'; expects_method(nil).to call(:find_application).on(rest_client).with('domain_o', 'app_o') }
    it("should split a path as an app")       { expects_method('domain/app').to call(:find_application).on(rest_client).with('domain', 'app') }

    context "when an app context is available" do
      before{ subject.stub(:app_context).and_return('app_s') }
      it("should assume app with -n and app context"){ options[:namespace] = 'domain_o'; expects_method(nil).to call(:find_application).on(rest_client).with('domain_o', 'app_s') }
    end
  end

  describe "rest_client" do
    let(:instance){ subject }
    before{ RHC::Rest::Client.any_instance.stub(:api_version_negotiated).and_return(1.4) }

    context "when initializing the object" do
      let(:auth){ double('auth') }
      let(:basic_auth){ double('basic_auth') }
      before{ RHC::Auth::Basic.should_receive(:new).at_least(1).times.with{ |arg| arg.should == instance.send(:options) }.and_return(basic_auth) }
      before{ RHC::Auth::Token.stub(:new).with{ |arg, arg2, arg3| [arg, arg2, arg3].should == [instance.send(:options), basic_auth, instance.send(:token_store)] }.and_return(auth) }

      context "with no options" do
        before{ subject.should_receive(:client_from_options).with(:auth => basic_auth) }
        it("should create only a basic auth object"){ subject.send(:rest_client) }
      end

      context "with use_authorization_tokens" do
        before{ subject.send(:options).use_authorization_tokens = true }
        before{ subject.should_receive(:client_from_options).with(:auth => auth) }
        it("should create a token auth object"){ subject.send(:rest_client) }
      end

      it { subject.send(:rest_client).should be_a(RHC::Rest::Client) }
      it { subject.send(:rest_client).should equal subject.send(:rest_client) }
    end

    context "from a command line" do
      subject{ Class.new(RHC::Commands::Base){ object_name :test; def run; 0; end } }
      let(:instance) { subject.new }
      let(:rest_client){ command_for(*arguments).send(:rest_client) }
      let(:basic_auth){ auth = rest_client.send(:auth); auth.is_a?(RHC::Auth::Basic) ? auth : auth.send(:auth) }
      let(:stored_token){ nil }
      before{ instance.send(:token_store).stub(:get).and_return(nil) unless stored_token }

      context "with credentials" do
        let(:arguments){ ['test', '-l', 'foo', '-p', 'bar'] }
        it { expect{ rest_client.user }.to call(:user).on(rest_client) }
      end

      context "without password" do
        let(:username){ 'foo' }
        let(:password){ 'bar' }
        let(:arguments){ ['test', '-l', username, '--server', mock_uri] }
        before{ stub_api; challenge{ stub_user(:user => username, :password => password) } }
        before{ basic_auth.should_receive(:ask).and_return(password) }
        it("asks for password") { rest_client.user }
      end

      context "without name or password" do
        let(:username){ 'foo' }
        let(:password){ 'bar' }
        let(:arguments){ ['test', '--server', mock_uri] }
        before{ stub_api; challenge{ stub_user(:user => username, :password => password) } }
        before{ basic_auth.should_receive(:ask).ordered.and_return(username) }
        before{ basic_auth.should_receive(:ask).ordered.and_return(password) }
        it("asks for password") { rest_client.user }
      end

      context "with token" do
        let(:username){ 'foo' }
        let(:token){ 'a_token' }
        let(:arguments){ ['test', '--token', token, '--server', mock_uri] }
        before{ stub_api(:token => token); stub_user(:token => token) }
        it("calls the server") { rest_client.user }
      end

      context "with username and a stored token" do
        let(:username){ 'foo' }
        let(:stored_token){ 'a_token' }
        let(:arguments){ ['test', '-l', username, '--server', mock_uri] }
        before{ stub_api; stub_user(:token => stored_token) }

        context "when tokens are not allowed" do
          it("calls the server") { rest_client.send(:auth).is_a? RHC::Auth::Basic }
          it("does not have a token set") { command_for(*arguments).send(:token_for_user).should be_nil }
        end

        context "when tokens are allowed" do
          let!(:config){ base_config{ |c, d| d.add('use_authorization_tokens', 'true') } }
          before{ instance.send(:token_store).should_receive(:get).with{ |user, server| user.should == username; server.should == instance.send(:openshift_server) }.and_return(stored_token) }
          it("has token set") { command_for(*arguments).send(:token_for_user).should == stored_token }
          it("calls the server") { rest_client.user }
        end
      end

      context "with username and tokens enabled" do
        let!(:config){ base_config{ |c, d| d.add('use_authorization_tokens', 'true') } }
        let(:username){ 'foo' }
        let(:auth_token){ double(:token => 'a_token') }
        let(:arguments){ ['test', '-l', username, '--server', mock_uri] }
        before{ instance.send(:token_store).should_receive(:get).with{ |user, server| user.should == username; server.should == instance.send(:openshift_server) }.and_return(nil) }
        before{ stub_api(false, true); stub_api_request(:get, 'broker/rest/user', false).to_return{ |request| request.headers['Authorization'] =~ /Bearer/ ? simple_user(username) : {:status => 401} } }
        it("should attempt to create a new token") do
          rest_client.should_receive(:new_session).ordered.and_return(auth_token)
          rest_client.user
        end
      end

      context "with username and tokens enabled against a server without tokens" do
        let!(:config){ base_config{ |c, d| d.add('use_authorization_tokens', 'true') } }
        let(:username){ 'foo' }
        let(:arguments){ ['test', '-l', username, '--server', mock_uri] }
        before{ instance.send(:token_store).should_receive(:get).with{ |user, server| user.should == username; server.should == instance.send(:openshift_server) }.and_return(nil) }
        before do 
          stub_api(false, false)
          stub_api_request(:get, 'broker/rest/user', false).to_return{ |request| request.headers['Authorization'] =~ /Basic/ ? simple_user(username) : {:status => 401, :headers => {'WWW-Authenticate' => 'Basic realm="openshift broker"'} } }
          stub_api_request(:get, 'broker/rest/user', {:user => username, :password => 'password'}).to_return{ simple_user(username) }
        end
        it("should prompt for password") do
          basic_auth.should_receive(:ask).once.and_return('password')
          rest_client.user
        end
      end
    end
  end
end

describe Commander::Command::Options do
  it{ subject.foo = 'bar'; subject.foo.should == 'bar' }
  it{ subject.foo = 'bar'; subject.respond_to?(:foo).should be_true }
  it{ subject.foo = lambda{ 'bar' }; subject.foo.should == 'bar' }
  it{ subject.foo = lambda{ 'bar' }; subject[:foo].should == 'bar' }
  it{ subject.foo = lambda{ 'bar' }; subject['foo'].should == 'bar' }
  it{ subject.foo = lambda{ 'bar' }; subject.__hash__[:foo].should be_a Proc }
  it{ subject[:foo] = lambda{ 'bar' }; subject.foo.should == 'bar' }
  it{ subject['foo'] = lambda{ 'bar' }; subject.foo.should == 'bar' }
  it{ subject.is_a?(Commander::Command::Options).should be_true }
  it{ expect{ subject.barf? }.to raise_error(NoMethodError) }
  it{ Commander::Command::Options.new(:foo => 1).foo.should == 1 }
end
