require 'spec_helper'
require 'rest_spec_helper'
require 'rhc'
require 'rhc/commands/account'

describe RHC::Commands::Account do

  describe '#run' do
    let(:arguments) { ['account'] }
    let(:username) { 'foo' }
    let(:password) { 'pass' }
    let(:server) { mock_uri }
    before{ user_config }
    before do
      stub_api(true)
      stub_user
    end

    it('should display the correct user') { run_output.should =~ /Login:\s*#{username}/ }
    it('should not show') { run_output.should_not =~ /Plan:/ }
    it('should show the gear capabilities') { run_output.should =~ /Allowed Gear Sizes:\s*small/ }
    it('should show the consumed gears') { run_output.should =~ /Gears Used:\s*0/ }
    it('should show the maximum gears') { run_output.should =~ /Gears Allowed:\s*3/ }
    it { expect { run }.to exit_with_code(0) }

    context 'with a free plan' do
      let(:user_plan_id){ 'free' }
      it('should show') { run_output.should =~ /Plan:\s*Free/ }
    end

    context 'with a silver plan' do
      let(:user_plan_id){ 'silver' }
      it('should show') { run_output.should =~ /Plan:\s*Silver/ }
    end

    context 'with a arbitrary plan' do
      let(:user_plan_id){ 'other' }
      it('should show') { run_output.should =~ /Plan:\s*Other/ }
    end
  end

  describe '#logout' do
    let(:arguments) { ['account', 'logout'] }
    let(:username) { 'foo' }
    let(:password) { nil }
    let(:supports_auth) { false }
    let(:server) { mock_uri }
    let!(:token_store) { RHC::Auth::TokenStore.new(Dir.mktmpdir) }
    before{ user_config }
    before do
      stub_api(mock_user_auth, supports_auth)
      stub_user
      RHC::Auth::TokenStore.should_receive(:new).at_least(1).and_return(token_store)
    end

    it("should clear the token cache"){ expect{ run }.to call(:clear).on(token_store) }
    it("should exit with success"){ expect{ run }.to exit_with_code(0) }
    it("should display a message"){ run_output.should match("All local sessions removed.") }

    context "when --all is requested" do
      let(:arguments) { ['account', 'logout', '--all'] }

      context "if the server does not implement authorizations" do
        it("should display a message"){ run_output.should match(/Deleting all authorizations associated with your account.*not supported/) }
        it("should exit with success"){ expect{ run }.to exit_with_code(0) }
      end

      context "if the server implements authorizations" do
        let(:supports_auth) { true }
        before{ stub_delete_authorizations }

        it("should display a message"){ run_output.should match(/Deleting all authorizations associated with your account.*done/) }
        it("should exit with success"){ expect{ run }.to exit_with_code(0) }
      end
    end

    context "when --token is provided" do
      let(:arguments) { ['account', 'logout', '--token', 'foo'] }
      def user_auth; { :token => 'foo' }; end

      context "if the server does not implement authorizations" do
        it("should display a message"){ run_output.should match(/Ending session on server.*not supported/) }
        it("should exit with success"){ expect{ run }.to exit_with_code(0) }
      end

      context "if the server implements authorizations" do
        let(:supports_auth) { true }

        context "if the server returns successfully" do
          before{ stub_delete_authorization('foo') }

          it("should display a message"){ run_output.should match(/Ending session on server.*deleted/) }
          it("should exit with success"){ expect{ run }.to exit_with_code(0) }
          it("should clear the token cache"){ expect{ run }.to call(:clear).on(token_store) }
        end

        context "if the server rejects the token" do
          before{ stub_request(:delete, mock_href('broker/rest/user/authorizations/foo', false)).to_return(:status => 401, :body => {}.to_json) }

          it("should display a message"){ run_output.should match(/Ending session on server.*already closed/) }
          it("should exit with success"){ expect{ run }.to exit_with_code(0) }
          it("should clear the token cache"){ expect{ run }.to call(:clear).on(token_store) }
        end

        context "if the server returns an unexpected error" do
          before{ stub_request(:delete, mock_href('broker/rest/user/authorizations/foo', false)).to_return(:status => 500, :body => {}.to_json) }

          it("should display a message"){ run_output.should match(/Ending session on server.*The server did not respond/) }
          it("should exit with success"){ expect{ run }.to exit_with_code(0) }
          it("should clear the token cache"){ expect{ run }.to call(:clear).on(token_store) }
        end
      end
    end
  end
end
