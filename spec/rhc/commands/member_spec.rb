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
    it('should output info about roles') { run_output.should match "Developers can collaborate" }
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

  let(:owner){ RHC::Rest::Membership::Member.new(:id => '1', :role => 'admin', :explicit_role => 'admin', :owner => true, :login => 'alice', :type => 'user') }
  let(:other_admin){ RHC::Rest::Membership::Member.new(:id => '2', :role => 'admin', :explicit_role => 'admin', :login => 'Bob', :type => 'user') }
  let(:other_editor){ RHC::Rest::Membership::Member.new(:id => '3', :role => 'edit', :explicit_role => 'edit', :name => 'Carol', :login => 'carol', :type => 'user') }
  let(:other_viewer){ RHC::Rest::Membership::Member.new(:id => '4', :role => 'view', :explicit_role => 'view', :name => 'Doug', :login => 'doug@doug.com', :type => 'user') }
  let(:other_viewer2){ RHC::Rest::Membership::Member.new(:id => '5', :role => 'view', :explicit_role => 'view', :name => 'ViewerC', :login => 'viewerc@viewer.com', :type => 'user') }
  let(:other_viewer3){ RHC::Rest::Membership::Member.new(:id => '6', :role => 'view', :explicit_role => 'view', :name => 'ViewerB', :login => 'viewerb@viewer.com', :type => 'user') }
  let(:other_viewer4){ RHC::Rest::Membership::Member.new(:id => '7', :role => 'view', :explicit_role => 'view', :name => 'ViewerA', :login => 'viewera@viewer.com', :type => 'user') }
  let(:team_admin){ RHC::Rest::Membership::Member.new(:id => '11', :role => 'admin', :explicit_role => 'admin', :name => 'team1', :type => 'team') }
  let(:team_editor){ RHC::Rest::Membership::Member.new(:id => '12', :role => 'edit', :explicit_role => 'edit', :name => 'team2', :type => 'team') }
  let(:team_viewer){ RHC::Rest::Membership::Member.new(:id => '13', :role => 'view', :explicit_role => 'view', :name => 'team3', :type => 'team') }
  let(:team_admin_member){ RHC::Rest::Membership::Member.new(:id => '21', :role => 'admin', :login => 'memberadmin', :type => 'user', :from => [{'id' => '11', 'type' => 'team'}]) }
  let(:team_editor_member){ RHC::Rest::Membership::Member.new(:id => '22', :role => 'edit', :login => 'membereditor', :type => 'user', :from => [{'id' => '12', 'type' => 'team'}]) }
  let(:team_viewer_member){ RHC::Rest::Membership::Member.new(:id => '23', :role => 'view', :login => 'memberviewer', :type => 'user', :from => [{'id' => '13', 'type' => 'team'}]) }
  let(:team_viewer_member2){ RHC::Rest::Membership::Member.new(:id => '24', :role => 'view', :login => 'memberviewer2', :type => 'user', :from => [{'id' => '13', 'type' => 'team'}]) }
  let(:team_viewer_member3){ RHC::Rest::Membership::Member.new(:id => '25', :role => 'view', :login => 'memberviewer3', :type => 'user', :from => [{'id' => '13', 'type' => 'team'}]) }
  let(:team_viewer_and_explicit_member){ RHC::Rest::Membership::Member.new(:id => '26', :role => 'view', :explicit_role => 'view', :login => 'memberviewerexplicitedit', :type => 'user', :from => [{'id' => '13', 'type' => 'team'}]) }

  describe 'show-domain' do
    context 'with members' do
      let(:arguments) { ['domain', 'show', 'mock-domain-0'] }
      let(:supports_members){ true }

      before{ with_mock_domain.add_member(owner).add_member(other_editor).add_member(other_admin).add_member(other_viewer).add_member(other_viewer2).add_member(other_viewer3).add_member(other_viewer4) }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /owned by alice/ }
      it { run_output.should =~ /Bob\s+\(admin\)/ }
      it { run_output.should =~ /<carol>\s+\(edit\)/ }
      it { run_output.should =~ /<doug@doug\.com>\s+\(view\)/ }
      it("should order the members by role then by name") { run_output.should =~ /Bob.*admin.*Admins.*Carol.*Editors.*ViewerA.*ViewerB.*ViewerC.*Viewers/m }
      it("should include the login value") { run_output.should =~ /alice.*Bob.*carol.*doug@doug\.com/m }
    end

  end

  describe 'list-member' do
    context 'on a domain with no members' do
      let(:arguments) { ['members', '-n', 'mock-domain-0'] }
      let(:supports_members){ true }
      before{ with_mock_domain.init_members }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /does not have any members/ }
    end

    context 'on a domain' do
      let(:arguments) { ['members', '-n', 'mock-domain-0'] }
      let(:supports_members){ true }
      before{ with_mock_domain.add_member(owner) }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /alice\s+admin \(owner\)/ }
      it("should not show the name column") { run_output.should =~ /^Login\s+Role\s+Type$/ }
    end

    context 'on a domain with teams not showing all members' do
      let(:arguments) { ['members', '-n', 'mock-domain-0'] }
      let(:supports_members){ true }
      before{ with_mock_domain.add_member(owner).add_member(team_admin).add_member(team_editor).add_member(team_admin_member).add_member(team_editor_member).add_member(team_viewer).add_member(team_viewer_and_explicit_member) }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /alice\s+alice\s+admin \(owner\)\s+user/ }
      it { run_output.should =~ /team1\s+admin\s+team/ }
      it { run_output.should_not =~ /memberadmin\s+memberadmin\s+admin \(via team1\)\s+user/ }
      it { run_output.should =~ /team2\s+edit\s+team/ }
      it { run_output.should_not =~ /membereditor\s+membereditor\s+edit \(via team2\)\s+user/ }
      it("should show the name column") { run_output.should =~ /^Name\s+Login\s+Role\s+Type$/ }
      it("should prompt to use the --all parameter") { run_output.should =~ /--all to display all members/ }
    end

    context 'on a domain with teams showing all members' do
      let(:arguments) { ['members', '-n', 'mock-domain-0', '--all'] }
      let(:supports_members){ true }
      before{ with_mock_domain.add_member(owner).add_member(team_admin).add_member(team_editor).add_member(team_admin_member).add_member(team_editor_member).add_member(team_viewer).add_member(team_viewer_and_explicit_member) }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /alice\s+alice\s+admin \(owner\)\s+user/ }
      it { run_output.should =~ /team1\s+admin\s+team/ }
      it { run_output.should =~ /memberadmin\s+memberadmin\s+admin \(via team1\)\s+user/ }
      it { run_output.should =~ /team2\s+edit\s+team/ }
      it { run_output.should =~ /membereditor\s+membereditor\s+edit \(via team2\)\s+user/ }
      it("should show the name column") { run_output.should =~ /^Name\s+Login\s+Role\s+Type$/ }
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
        it("should not show the name column") { run_output.should =~ /^Login\s+Role\s+Type$/ }

        context "with ids" do
          let(:arguments) { ['members', 'mock-domain-0/mock-app-0', '--ids'] }
          it { expect { run }.to exit_with_code(0) }
          it { run_output.should =~ /alice\s+admin \(owner\) 1/ }
          it("should not show the name column") { run_output.should =~ /^Login\s+Role\s+ID\s+Type$/ }
        end
      end

      context "with several members" do
        let(:supports_members){ true }
        before{ with_mock_app.add_member(owner).add_member(other_editor).add_member(other_admin).add_member(other_viewer) }
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /alice\s+admin \(owner\)/ }
        it { run_output.should =~ /Bob\s+admin/ }
        it { run_output.should =~ /carol\s+edit/ }
        it { run_output.should =~ /doug\.com\s+view/ }
        it("should order the members by role") { run_output.should =~ /admin.*owner.*admin.*edit.*view/m }
        it("should include the login value") { run_output.should =~ /alice.*Bob.*carol.*doug@doug\.com/m }
        it("should show the name column") { run_output.should =~ /^Name\s+Login\s+Role\s+Type$/ }
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

    context "when the client doesn't support teams" do
      let(:mock_teams_links){ [] }
      let(:arguments) { ['add-member', 'testteam', '-n', 'test', '--type', 'team'] }
      it { expect { run }.to exit_with_code(161) }
      it { run_output.should =~ /Adding 1 editor to domain .*Server does not support teams/ }
    end

    context "with supported membership" do
      let(:supports_members?){ true }

      context 'with a valid user' do
        let(:arguments) { ['add-member', 'testuser', '-n', 'test'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'edit', 'type' => 'user'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'info', :text => 'Added 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Adding 1 editor to domain .*done/ }
      end

      context 'with a valid team' do
        let(:arguments) { ['add-member', 'testteam', '-n', 'test', '--type', 'team'] }
        before do
          challenge do
            stub_api_request(:get, "broker/rest/teams?owner=@self").
              to_return({:body => {:type => 'teams', :data => [{:id => 111, :global => false, :name => 'testteam'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
          end
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{:role => 'edit', :type => 'team', :id => 111, }]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'id', :index => 0, :severity => 'info', :text => 'Added 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Adding 1 editor to domain .*done/ }
      end

      context 'with an invalid type' do
        let(:arguments) { ['add-member', 'invalidteam', '-n', 'test', '--type', 'foo'] }
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Type must be/ }
      end

      context 'with an invalid team' do
        let(:arguments) { ['add-member', 'invalidteam', '-n', 'test', '--type', 'team'] }
        before do
          challenge do
            stub_api_request(:get, "broker/rest/teams?owner=@self").
              to_return({:body => {:type => 'teams', :data => [{:id => 111, :global => false, :name => 'testteam'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
          end
        end
        it { expect { run }.to exit_with_code(162) }
        it { run_output.should =~ /Adding 1 editor to domain .*You do not have a team named 'invalidteam'/ }
      end

      context 'with multiple partial team matches but one exact match' do
        let(:arguments) { ['add-member', 'testteam', '-n', 'test', '--type', 'team'] }
        before do
          challenge do
            stub_api_request(:get, "broker/rest/teams?owner=@self").
              to_return({:body => {:type => 'teams', :data => [{:id => 111, :global => false, :name => 'testteam'}, {:id => 222, :global => false, :name => 'testteam1'}, {:id => 333, :global => false, :name => 'testteam11'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
          end
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{:role => 'edit', :type => 'team', :id => 111, }]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'id', :index => 0, :severity => 'info', :text => 'Added 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Adding 1 editor to domain .*done/ }
      end

      context 'without an exact team match' do
        let(:arguments) { ['add-member', 'team', '-n', 'test', '--type', 'team'] }
        before do
          challenge do
            stub_api_request(:get, "broker/rest/teams?owner=@self").
              to_return({:body => {:type => 'teams', :data => [{:id => 111, :global => false, :name => 'team1'}, {:id => 111, :global => false, :name => 'team2'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
          end
        end
        it { expect { run }.to exit_with_code(162) }
        it { run_output.should =~ /Adding 1 editor to domain .*You do not have a team named 'team'. Did you mean one of the following\?\nteam1, team2/ }
      end

      context 'with a single exact case insensitive match' do
        let(:arguments) { ['add-member', 'testteam', '-n', 'test', '--type', 'team'] }
        before do
          challenge do
            stub_api_request(:get, "broker/rest/teams?owner=@self").
              to_return({:body => {:type => 'teams', :data => [{:id => 111, :global => false, :name => 'TESTTEAM'}, {:id => 222, :global => false, :name => 'TESTTEAM1'}, {:id => 333, :global => false, :name => 'TESTTEAM2'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
          end
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{:role => 'edit', :type => 'team', :id => 111, }]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'id', :index => 0, :severity => 'info', :text => 'Added 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Adding 1 editor to domain .*done/ }
      end

      context 'with an exact case sensitive match and some exact case insensitive matches' do
        let(:arguments) { ['add-member', 'testteam', '-n', 'test', '--type', 'team'] }
        before do
          challenge do
            stub_api_request(:get, "broker/rest/teams?owner=@self").
              to_return({:body => {:type => 'teams', :data => [{:id => 111, :global => false, :name => 'testteam'}, {:id => 222, :global => false, :name => 'TESTTEAM'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
          end
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{:role => 'edit', :type => 'team', :id => 111, }]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'id', :index => 0, :severity => 'info', :text => 'Added 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Adding 1 editor to domain .*done/ }
      end

      context 'with a team name containing special characters' do
        let(:arguments) { ['add-member', '*1()', '-n', 'test', '--type', 'team'] }
        before do
          challenge do
            stub_api_request(:get, "broker/rest/teams?owner=@self").
              to_return({:body => {:type => 'teams', :data => [{:id => 111, :global => false, :name => '*1()'}, {:id => 222, :global => false, :name => 'another team'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
          end
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{:role => 'edit', :type => 'team', :id => 111, }]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'id', :index => 0, :severity => 'info', :text => 'Added 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Adding 1 editor to domain .*done/ }
      end

      context 'with multiple exact team matches' do
        let(:arguments) { ['add-member', 'someteam', '-n', 'test', '--type', 'team'] }
        before do
          challenge do
            stub_api_request(:get, "broker/rest/teams?owner=@self").
              to_return({:body => {:type => 'teams', :data => [{:id => 111, :global => false, :name => 'someteam'}, {:id => 222, :global => false, :name => 'someteam'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
          end
        end
        it { expect { run }.to exit_with_code(162) }
        it { run_output.should =~ /Adding 1 editor to domain .*There is more than one team named 'someteam'\. Please use the --ids flag and specify the exact id of the team you want to manage\./ }
      end

      context 'with multiple case-insensitive team matches' do
        let(:arguments) { ['add-member', 'someteam', '-n', 'test', '--type', 'team'] }
        before do
          challenge do
            stub_api_request(:get, "broker/rest/teams?owner=@self").
              to_return({:body => {:type => 'teams', :data => [{:id => 111, :global => false, :name => 'SOMETEAM'}, {:id => 222, :global => false, :name => 'SomeTeam'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
          end
        end
        it { expect { run }.to exit_with_code(162) }
        it { run_output.should =~ /Adding 1 editor to domain .*You do not have a team named 'someteam'. Did you mean one of the following\?\nSOMETEAM, SomeTeam/ }
      end

      context 'without a global team' do
        let(:arguments) { ['add-member', 'testteam', '-n', 'test', '--type', 'team', '--global'] }
        before do
          challenge do
            stub_api_request(:get, "broker/rest/teams?global&search=testteam").
              to_return({:body => {:type => 'teams', :data => [], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
          end
        end
        it { expect { run }.to exit_with_code(162) }
        it { run_output.should =~ /Adding 1 editor to domain .*No global team found with the name 'testteam'\./ }
      end

      context 'with an invalid role' do
        let(:arguments) { ['add-member', 'testuser', '-n', 'test', '--role', 'missing'] }
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /The provided role 'missing' is not valid\. Supported values: .*admin/ }
      end

      context 'with a missing user' do
        let(:arguments) { ['add-member', 'testuser', '-n', 'test', '--type', 'user'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'edit', 'type' => 'user'}]}).
            to_return({:body => {:messages => [{:exit_code => 132, :field => 'login', :index => 0, :severity => 'error', :text => 'There is no user with a login testuser'},]}.to_json, :status => 422})
        end
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Adding 1 editor to domain.*There is no user with a login testuser/ }
      end

      context 'with a missing user id and role' do
        let(:arguments) { ['add-member', '123', '-n', 'test', '--ids', '--role', 'admin'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'id' => '123', 'role' => 'admin', 'type' => 'user'}]}).
            to_return({:body => {:messages => [{:exit_code => 132, :field => 'id', :index => 0, :severity => 'error', :text => 'There is no user with the id 123'},]}.to_json, :status => 422})
        end
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Adding 1 administrator to domain.*There is no user with the id 123/ }
      end
    end
  end

  describe 'update-member' do
    context "when the resource doesn't support membership changes" do
      before{ stub_api }

      context "when updating a domain" do
        let(:arguments) { ['update-member', 'testuser', '-n', 'test'] }
        before{ challenge{ stub_one_domain('test', nil, mock_user_auth) } }
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Updating 1 editor to domain .*The server does not support adding or removing members/ }
      end
    end

    context "with supported membership" do
      let(:supports_members?){ true }
      before do
        stub_api
        challenge{ stub_one_domain('test', nil, mock_user_auth) }
      end

      context 'with a valid user' do
        let(:arguments) { ['update-member', 'testuser', '-n', 'test', '-r', 'view'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'view', 'type' => 'user'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'info', :text => 'Updated 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Updating 1 viewer to domain .*done/ }
      end

      context 'with a valid team' do
        let(:arguments) { ['update-member', 'testteam', '-n', 'test', '-r', 'view', '--type', 'team'] }
        before do
          stub_api_request(:get, "broker/rest/domains/test/members").
            to_return({:body => {:type => 'members', :data => [{:id => 1, :name => 'testteam', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing members'},]}.to_json, :status => 200})
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'id' => 1, 'role' => 'view', 'type' => 'team'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'info', :text => 'Updated 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Updating 1 viewer to domain .*done/ }
      end

      context 'with multiple team exact matches' do
        let(:arguments) { ['update-member', 'testteam', '-n', 'test', '-r', 'view', '--type', 'team'] }
        before do
          stub_api_request(:get, "broker/rest/domains/test/members").
            to_return({:body => {:type => 'members', :data => [{:id => 1, :name => 'testteam', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}, {:id => 12, :name => 'testteam', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing members'},]}.to_json, :status => 200})
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'id' => 1, 'role' => 'view', 'type' => 'team'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'info', :text => 'Updated 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(163) }
        it { run_output.should =~ /Updating 1 viewer to domain .*There is more than one team named 'testteam'/ }
      end

      context 'with multiple team case-insensitive matches' do
        let(:arguments) { ['update-member', 'testteam', '-n', 'test', '-r', 'view', '--type', 'team'] }
        before do
          stub_api_request(:get, "broker/rest/domains/test/members").
            to_return({:body => {:type => 'members', :data => [{:id => 1, :name => 'TESTTEAM', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}, {:id => 12, :name => 'TestTeam', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing members'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(162) }
        it { run_output.should =~ /Updating 1 viewer to domain .*No team found with the name 'testteam'. Did you mean one of the following\?\nTESTTEAM, TestTeam/ }
      end

      context 'with a single exact case insensitive match' do
        let(:arguments) { ['update-member', 'testteam', '-n', 'test', '-r', 'view', '--type', 'team'] }
        before do
          stub_api_request(:get, "broker/rest/domains/test/members").
            to_return({:body => {:type => 'members', :data => [{:id => 1, :name => 'TESTTEAM', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}, {:id => 2, :name => 'TESTTEAM2', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}, {:id => 3, :name => 'TESTTEAM3', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing members'},]}.to_json, :status => 200})
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'id' => 1, 'role' => 'view', 'type' => 'team'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'info', :text => 'Updated 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Updating 1 viewer to domain .*done/ }
      end

      context 'with an exact case sensitive match and some exact case insensitive matches' do
        let(:arguments) { ['update-member', 'testteam', '-n', 'test', '-r', 'view', '--type', 'team'] }
        before do
          stub_api_request(:get, "broker/rest/domains/test/members").
            to_return({:body => {:type => 'members', :data => [{:id => 1, :name => 'testteam', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}, {:id => 2, :name => 'TESTTEAM', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}, {:id => 3, :name => 'TeStTeAm', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing members'},]}.to_json, :status => 200})
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'id' => 1, 'role' => 'view', 'type' => 'team'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'info', :text => 'Updated 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Updating 1 viewer to domain .*done/ }
      end

      context 'with a team name containing special characters' do
        let(:arguments) { ['update-member', '*1()', '-n', 'test', '-r', 'view', '--type', 'team'] }
        before do
          stub_api_request(:get, "broker/rest/domains/test/members").
            to_return({:body => {:type => 'members', :data => [{:id => 1, :name => '*1()', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'team'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing members'},]}.to_json, :status => 200})
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'id' => 1, 'role' => 'view', 'type' => 'team'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'info', :text => 'Updated 1 member'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Updating 1 viewer to domain .*done/ }
      end

      context 'with a missing user' do
        let(:arguments) { ['update-member', 'testuser', '-n', 'test', '-r', 'view'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'view', 'type' => 'user'}]}).
            to_return({:body => {:messages => [{:exit_code => 132, :field => 'login', :index => 0, :severity => 'error', :text => 'There is no user with a login testuser'},]}.to_json, :status => 422})
        end
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Updating 1 viewer to domain.*There is no user with a login testuser/ }
      end

      context 'with a missing team' do
        let(:arguments) { ['update-member', 'testteam', '-n', 'test', '-r', 'view', '--type', 'team'] }
        before do
          stub_api_request(:get, "broker/rest/domains/test/members").
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing teams'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(163) }
        it { run_output.should =~ /Updating 1 viewer to domain.*No team found with the name 'testteam'/ }
      end

      context 'with a missing team with an identical user name' do
        let(:arguments) { ['update-member', 'testteam', '-n', 'test', '-r', 'view', '--type', 'team'] }
        before do
          stub_api_request(:get, "broker/rest/domains/test/members").
            to_return({:body => {:type => 'members', :data => [{:id => 1, :name => 'testteam', :login => 'testteam', :owner => false, :role => 'edit', :explicit_role => 'edit', :type => 'user'}], :messages => [{:exit_code => 0, :field => nil, :index => nil, :severity => 'info', :text => 'Listing members'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(163) }
        it { run_output.should =~ /Updating 1 viewer to domain.*No team found with the name 'testteam'/ }
      end

      context 'with a missing user id and role' do
        let(:arguments) { ['update-member', '123', '-n', 'test', '--ids', '-r', 'view'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'id' => '123', 'role' => 'view', 'type' => 'user'}]}).
            to_return({:body => {:messages => [{:exit_code => 132, :field => 'id', :index => 0, :severity => 'error', :text => 'There is no user with the id 123'},]}.to_json, :status => 422})
        end
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Updating 1 viewer to domain.*There is no user with the id 123/ }
      end

      context 'when the user is not a member' do
        let(:arguments) { ['update-member', 'testuser', '-n', 'test', '-r', 'view'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'view', 'type' => 'user'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'warning', :text => 'testuser is not a member of this domain.'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Updating 1 viewer to domain.*testuser is not a member of this domain.*done/m }
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
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'none', 'type' => 'user'}]}).
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
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'none', 'type' => 'user'}]}).
            to_return({:body => {:messages => [{:exit_code => 132, :field => 'login', :index => 0, :severity => 'error', :text => 'There is no user with a login testuser'},]}.to_json, :status => 422})
        end
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Removing 1 member from domain.*There is no user with a login testuser/ }
      end

      context 'with a missing user id and role' do
        let(:arguments) { ['remove-member', '123', '-n', 'test', '--ids'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'id' => '123', 'role' => 'none', 'type' => 'user'}]}).
            to_return({:body => {:messages => [{:exit_code => 132, :field => 'id', :index => 0, :severity => 'error', :text => 'There is no user with the id 123'},]}.to_json, :status => 422})
        end
        it { expect { run }.to exit_with_code(1) }
        it { run_output.should =~ /Removing 1 member from domain.*There is no user with the id 123/ }
      end

      context 'when the user is not a member' do
        let(:arguments) { ['remove-member', 'testuser', '-n', 'test'] }
        before do
          stub_api_request(:patch, "broker/rest/domains/test/members").
            with(:body => {:members => [{'login' => 'testuser', 'role' => 'none', 'type' => 'user'}]}).
            to_return({:body => {:type => 'members', :data => [], :messages => [{:exit_code => 0, :field => 'login', :index => 0, :severity => 'warning', :text => 'testuser is not a member of this domain.'},]}.to_json, :status => 200})
        end
        it { expect { run }.to exit_with_code(0) }
        it { run_output.should =~ /Removing 1 member from domain.*testuser is not a member of this domain.*done/m }
      end
    end
  end
end