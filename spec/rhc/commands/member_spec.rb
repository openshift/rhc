require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/member'

describe RHC::Commands::Member do

  before{ user_config }

  describe 'help' do
    let(:arguments) { ['member', '--help'] }

    it "should display help" do
      expect { run }.to exit_with_code(0)
    end
    it('should output usage') { run_output.should match "Usage: rhc member" }
    it('should output info about roles') { run_output.should match "Teams of developers can collaborate" }
  end

  let(:username){ 'test_user' }
  let(:password){ 'test_password' }
  let(:server){ 'test.domain.com' }

  def with_mock_rest_client
    @rest_client ||= MockRestClient.new
  end
  def with_mock_domain
    @domain ||= with_mock_rest_client.add_domain("mock-domain-0")
  end
  def with_mock_app
    @app ||= begin
      app = with_mock_domain.add_application("mock-app-0", "ruby-1.8.7")
      app.stub(:ssh_url).and_return("ssh://user@test.domain.com")
      app.stub(:supports_members?).and_return(supports_members)
      app
    end
  end

  let(:owner){ RHC::Rest::Membership::Member.new(:id => '1', :role => 'admin', :owner => true, :login => 'alice') }
  let(:other_admin){ RHC::Rest::Membership::Member.new(:id => '2', :role => 'admin', :login => 'Bob') }
  let(:other_editor){ RHC::Rest::Membership::Member.new(:id => '3', :role => 'editor', :name => 'Carol', :login => 'carol') }
  let(:other_viewer){ RHC::Rest::Membership::Member.new(:id => '4', :role => 'viewer', :name => 'Doug', :login => 'doug@doug.com') }

  describe 'list-member' do
    context 'on a domain' do
      let(:arguments) { ['members', '-n', 'mock-domain-0'] }
      let(:supports_members){ true }
      before{ with_mock_domain.add_member(owner) }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /alice\s+admin \(owner\)/ }
      it("should not show the name column") { run_output.should =~ /^Login\s+Role$/ }
    end

    context 'on an application' do
      let(:arguments) { ['members', 'mock-domain-0/mock-app-0'] }
      let(:supports_members){ false }
      before{ with_mock_app }

      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /The server does not support adding or removing members/ }

      context "with only owner" do
        let(:supports_members){ true }
        before{ with_mock_app.add_member(owner) }
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /alice\s+admin \(owner\)/ }
        it("should not show the name column") { run_output.should =~ /^Login\s+Role$/ }

        context "with ids" do
          let(:arguments) { ['members', 'mock-domain-0/mock-app-0', '--ids'] }
          it { expect { run }.to exit_with_code(0) }
          it { run_output.should =~ /alice\s+admin \(owner\) 1/ }
          it("should not show the name column") { run_output.should =~ /^Login\s+Role\s+ID$/ }
        end
      end

      context "with several members" do
        let(:supports_members){ true }
        before{ with_mock_app.add_member(owner).add_member(other_editor).add_member(other_admin).add_member(other_viewer) }
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /alice\s+admin \(owner\)/ }
        it { run_output.should =~ /Bob\s+admin/ }
        it { run_output.should =~ /carol\s+editor/ }
        it { run_output.should =~ /doug\.com\s+viewer/ }
        it("should order the members by role") { run_output.should =~ /admin.*owner.*admin.*edit.*view/m }
        it("should include the login value") { run_output.should =~ /alice.*Bob.*carol.*doug@doug\.com/m }
        it("should show the name column") { run_output.should =~ /^Name\s+Login\s+Role$/ }
      end
    end
  end

  describe 'add-member' do
    before do
      stub_api
      challenge{ stub_one_domain('test', nil, mock_user_auth) }
    end

    context "when the resource doesn't support membership changes" do
      let(:arguments) { ['add-member', 'testuser', '-n', 'test'] }
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /Adding 1 editor to domain .*The server does not support adding or removing members/ }
    end

    context "with supported membership" do
      let(:supports_members?){ true }

      context 'with a valid user' do
        let(:arguments) { ['add-member', 'testuser', '-n', 'test'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'edit'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'info', :text => 'Added 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Adding 1 editor to domain .*done/ }
      end

      context 'with an invalid role' do
        let(:arguments) { ['add-member', 'testuser', '-n', 'test', '--role', 'missing'] }
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /The provided role 'missing' is not valid\. Supported values: .*admin/ }
      end

      context 'with a missing user' do
        let(:arguments) { ['add-member', 'testuser', '-n', 'test'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'edit'}]}).
            to_return({:body => {:messages => [{:exit_code => 132, :field => 'login', :index => 0, :severity => 'error', :text => 'There is no user with a login testuser'},]}.to_json, :status => 422})
        end
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Adding 1 editor to domain.*There is no user with a login testuser/ }
      end

      context 'with a missing user id and role' do
        let(:arguments) { ['add-member', '123', '-n', 'test', '--ids', '--role', 'admin'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'id' => '123', 'role' => 'admin'}]}).
            to_return({:body => {:messages => [{:exit_code => 132, :field => 'id', :index => 0, :severity => 'error', :text => 'There is no user with the id 123'},]}.to_json, :status => 422})
        end
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Adding 1 administrator to domain.*There is no user with the id 123/ }
      end
    end
  end

  describe 'remove-member' do
    context "when the resource doesn't support membership changes" do
      before{ stub_api }

      context "when adjusting a domain" do
        let(:arguments) { ['remove-member', 'testuser', '-n', 'test'] }
        before{ challenge{ stub_one_domain('test', nil, mock_user_auth) } }
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Removing 1 member from domain .*The server does not support adding or removing members/ }
      end
    end

    context "with supported membership" do
      let(:supports_members?){ true }
      before do
        stub_api
        challenge{ stub_one_domain('test', nil, mock_user_auth) }
      end
=begin Scenario removed
      context "when adjusting an app" do
        let(:arguments) { ['remove-member', 'testuser', '-n', 'test', '-a', 'app'] }
        before{ challenge{ stub_one_application('test', 'app') } }
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /You can only add or remove members on a domain/ }
      end
=end
      context 'with a valid member' do
        let(:arguments) { ['remove-member', 'testuser', '-n', 'test'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'none'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'info', :text => 'Removed 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Removing 1 member from domain .*done/ }
      end

      context 'with --all' do
        let(:arguments) { ['remove-member', '--all', '-n', 'test'] }
        before do
          stub_api_request(:delete, "broker/rest/domains/test/members").
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'info', :text => 'Removed everyone except owner.'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Removing all members from domain .*done/ }
      end

      context 'with a missing user' do
        let(:arguments) { ['remove-member', 'testuser', '-n', 'test'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'none'}]}).
            to_return({:body => {:messages => [{:exit_code => 132, :field => 'login', :index => 0, :severity => 'error', :text => 'There is no user with a login testuser'},]}.to_json, :status => 422})
        end
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Removing 1 member from domain.*There is no user with a login testuser/ }
      end

      context 'with a missing user id and role' do
        let(:arguments) { ['remove-member', '123', '-n', 'test', '--ids'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'id' => '123', 'role' => 'none'}]}).
            to_return({:body => {:messages => [{:exit_code => 132, :field => 'id', :index => 0, :severity => 'error', :text => 'There is no user with the id 123'},]}.to_json, :status => 422})
        end
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Removing 1 member from domain.*There is no user with the id 123/ }
      end

      context 'when the user isn''t a member' do
        let(:arguments) { ['remove-member', 'testuser', '-n', 'test'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'none'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'warning', :text => 'testuser is not a member of this domain.'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Removing 1 member from domain.*testuser is not a member of this domain.*done/m }
      end
    end
  end
end