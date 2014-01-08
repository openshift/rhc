require 'spec_helper'
require 'rest_spec_helper'
require 'rhc'
require 'rhc/commands/authorization'

describe RHC::Commands::Authorization do

  def self.with_authorization
    let(:username) { 'foo' }
    let(:password) { 'pass' }
    let(:server) { mock_uri }
    before{ user_config }
    before{ stub_api(false, true) }
  end
  def self.without_authorization
    let(:username) { 'foo' }
    let(:password) { 'pass' }
    let(:server) { mock_uri }
    before{ user_config }
    before{ stub_api(false, false) }
  end
  def self.expect_an_unsupported_message
    context "without authorizations" do
      without_authorization
      it('should warn that the server doesn\'t support auth'){ run_output.should =~ /The server does not support setting, retrieving, or authenticating with authorization tokens/ }
      it{ expect{ run }.to exit_with_code(1) }
    end
  end

  describe '#run' do
    let(:arguments) { ['authorizations'] }
    context "with authorizations" do
      with_authorization
      before{ challenge{ stub_authorizations } }
      it('should display the note')           { run_output.should =~ /an_authorization/ }
      it('should display the token')          { run_output.should =~ /Token:\s+a_token_value/ }
      it('should display the expiration')     { run_output.should =~ /Expires In:\s+1 minute/ }
      it('should display the creation date')  { run_output.should =~ /Created:\s+#{RHC::Helpers.date('2013-02-21T01:00:01Z')}/ }
      it('should display the scopes')         { run_output.should =~ /Scopes:\s+session read/ }
      it{ expect{ run }.to exit_with_code(0) }
    end

    expect_an_unsupported_message
  end

  describe '#run' do
    let(:arguments) { ['authorization']}
    context 'given no arguments' do
      it('should display help'){ run_output.should =~ /An authorization token grants access to the OpenShift REST API.*To see all your authorizations/m }
      it 'should ask for an argument' do
        expect{ run }.to exit_with_code(1)
      end
    end
  end

  describe '#list' do
    let(:arguments) { ['authorization', 'list'] }
    context "with authorizations" do
      with_authorization
      before{ challenge{ stub_authorizations } }
      it('should display the note')           { run_output.should =~ /an_authorization/ }
      it('should display the token')          { run_output.should =~ /Token:\s+a_token_value/ }
      it('should display the expiration')     { run_output.should =~ /Expires In:\s+1 minute/ }
      it('should display the creation date')  { run_output.should =~ /Created:\s+#{RHC::Helpers.date('2013-02-21T01:00:01Z')}/ }
      it('should display the scopes')         { run_output.should =~ /Scopes:\s+session read/ }
      it{ expect{ run }.to exit_with_code(0) }
    end

    expect_an_unsupported_message
  end

  describe "#delete" do
    let(:arguments) { ['authorization', 'delete', 'foo', 'bar'] }

    context "with authorizations" do
      with_authorization
      before{ challenge{ stub_delete_authorization('foo') } }
      before{ challenge{ stub_delete_authorization('bar') } }
      it('should display success') { run_output.should =~ /Deleting auth.*done/ }
      it{ expect{ run }.to exit_with_code(0) }
      after{ a_request(:delete, mock_href('broker/rest/user/authorizations/foo', true)).should have_been_made }
      after{ a_request(:delete, mock_href('broker/rest/user/authorizations/bar', true)).should have_been_made }
    end

    context "without a token in the command line" do
      let(:arguments) { ['authorization', 'delete'] }
      it('should display success') { run_output.should =~ /You must specify one or more tokens to delete/ }
      it{ expect{ run }.to exit_with_code(1) }
    end

    expect_an_unsupported_message
  end

  describe "#delete_all" do
    let(:arguments) { ['authorization', 'delete-all'] }

    context "with authorizations" do
      with_authorization
      before{ challenge{ stub_delete_authorizations } }
      it('should display success') { run_output.should =~ /Deleting all auth.*done/ }
      it{ expect{ run }.to exit_with_code(0) }
      after{ a_request(:delete, mock_href('broker/rest/user/authorizations', true)).should have_been_made }
    end

    expect_an_unsupported_message
  end

  describe "#scope_help" do
    let(:rest_client){ double(:authorization_scope_list => [['scope_1', 'A description'], ['scope_2', 'Another description']]) }
    before{ subject.should_receive(:rest_client).and_return(rest_client) }
    it{ capture{ subject.send(:scope_help) }.should =~ /scope_1.*A description/ }
    it{ capture{ subject.send(:scope_help) }.should =~ /scope_2.*Another description/ }
    it{ capture{ subject.send(:scope_help) }.should =~ /You may pass multiple scopes/ }
  end

  describe "#add" do
    let(:arguments) { ['authorization', 'add'] }

    context "with authorizations" do
      using_command_instance
      with_authorization
      before{ instance.should_receive(:scope_help) }

      it('should display the scope help') { command_output.should =~ /When adding an authorization.*to see more options/m }
      it{ expect{ run_command }.to exit_with_code(0) }
    end

    expect_an_unsupported_message

    context "with empty scope options" do
      let(:arguments) { ['authorization', 'add', '--scopes', ' ', '--note', 'a_note', '--expires-in', '300'] }
      using_command_instance
      with_authorization
      before{ instance.should_receive(:scope_help) }

      it('should display the scope help') { command_output.should =~ /When adding an authorization.*to see more options/m }
      it{ expect{ run_command }.to exit_with_code(0) }
    end

    context "with options" do
      let(:arguments) { ['authorization', 'add', '--scope', 'foo,bar', '--note', 'a_note', '--expires-in', '300'] }
      with_authorization
      before{ challenge{ stub_add_authorization(:note => 'a_note', :scope => 'foo,bar', :expires_in => '300') } }

      it('should display success') { run_output.should =~ /Adding authorization.*done/ }
      it('should display the note')           { run_output.should =~ /a_note/ }
      it('should display the token')          { run_output.should =~ /Token:\s+a_token_value/ }
      it('should display the expiration')     { run_output.should =~ /Expires In:\s+5 minutes/ }
      it('should display the creation date')  { run_output.should =~ /Created:\s+#{RHC::Helpers.date(mock_date_1)}/ }
      it('should display the scopes')         { run_output.should =~ /Scopes:\s+foo bar/ }
      it{ expect{ run }.to exit_with_code(0) }

      expect_an_unsupported_message
    end
  end
end
