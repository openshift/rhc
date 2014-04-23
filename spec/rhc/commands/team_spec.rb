require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/team'

describe RHC::Commands::Team do
  let(:rest_client){ MockRestClient.new }
  before{ 
    user_config
  }

  describe 'default action' do
    before{ rest_client }
    context 'when run with no teams' do
      let(:arguments) { ['team'] }

      it { expect { run }.to exit_with_code(1) }
      it { run_output.should match(/To create.*rhc create-team/m) }
    end
    context 'when help is shown' do
      let(:arguments) { ['team', '--noprompt', '--help'] }

      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match(/create.*delete.*leave.*list/m) }
    end
  end

  describe 'show' do
    before{ rest_client }

    context 'when run with no teams' do
      let(:arguments) { ['team', 'show'] }
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should match(/specify a team name/) }
    end

    context 'when run with one team' do
      let(:arguments) { ['team', 'show', 'oneteam'] }
      before{ rest_client.add_team("oneteam") }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match(/oneteam/) }
      it { run_output.should match(/ID: 123/) }
    end

    context 'when run with two teams' do
      let(:arguments) { ['team', 'show', 'twoteam'] }
      before do
        rest_client.add_team("oneteam")
        rest_client.add_team("twoteam") 
      end
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match(/twoteam/) }
      it { run_output.should_not match(/oneteam/) }
    end
  end

  describe 'list' do
    before{ rest_client }
    let(:arguments) { ['team', 'list'] }

    context 'when run with no teams' do
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match(/member of 0 teams/) }
    end

    context 'when run with one team' do
      before{ rest_client.add_team("oneteam") }

      it { expect { run }.to exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("You are a member of 1 team\\.")
        output.should match("oneteam")
      end

      context 'when has no members' do
        before{ rest_client.teams.first.attributes.merge(:members => nil, :id => '123') }
        it { expect { run }.to exit_with_code(0) }
        it "should match output" do
          output = run_output
          output.should match("oneteam")
          output.should_not match ("Members:")
          output.should match ("ID: 123")
        end
      end

      context 'when an ID is present and differs from name' do
        let(:arguments) { ['team', 'list'] }
        before{ rest_client.teams.first.attributes['id'] = '123' }
        it { expect { run }.to exit_with_code(0) }
        it "should match output" do
          output = run_output
          output.should match("oneteam")
          output.should match ("ID:.*123")
        end
      end

    end

    context 'when run with one owned team' do
      let(:arguments) { ['teams', '--mine'] }
      before{ t = rest_client.add_team('mine', true); rest_client.stub(:owned_teams).and_return([t]) }

      it { expect { run }.to exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("You have 1 team\\.")
        output.should match("mine")
      end
    end
  end

  describe 'create' do
    before{ rest_client }
    let(:arguments) { ['team', 'create', 'testname'] }

    context 'when no issues with ' do

      it "should create a team" do
        expect { run }.to exit_with_code(0)
        rest_client.teams[0].name.should == 'testname'
      end
      it { run_output.should match(/Creating.*'testname'.*done/m) }
    end
  end

  describe 'leave' do
    before{ rest_client.add_team("deleteme") }
    let(:arguments) { ['team', 'leave', 'deleteme'] }

    it "should leave the team" do
      rest_client.teams.first.should_receive(:leave).and_return(RHC::Rest::Membership::Member.new)
      expect { run }.to exit_with_code(0)
    end
  end

  describe 'delete' do
    before{ rest_client }
    let(:arguments) { ['team', 'delete', 'deleteme'] }

    context 'when no issues with ' do
      before{ 
        t = rest_client.add_team("deleteme")
        rest_client.should_receive(:owned_teams).and_return([t])
      }

      it "should delete a team" do
        expect { run }.to exit_with_code(0)
        rest_client.teams.empty?.should be_true
      end
    end

    context 'when there is a different team' do
      before do
        t = rest_client.add_team("dontdelete")
        rest_client.should_receive(:owned_teams).and_return([t])
      end

      it "should error out" do
        expect { run }.to exit_with_code(162)
        rest_client.teams[0].name.should == 'dontdelete'
      end
      it { run_output.should match("Team with name deleteme not found") }
    end

  end

  describe 'help' do
    let(:arguments) { ['team', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc team") }
    end
  end
end
