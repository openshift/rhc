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

  let(:owner){ RHC::Rest::Membership::Member.new(:id => '1', :role => 'admin', :owner => true, :name => 'Bob') }

  describe 'list-member' do
    let(:supports_members){ false }
    let(:arguments) { ['members', 'mock-domain-0/mock-app-0'] }
    before{ with_mock_app }

    it { expect { run }.to exit_with_code(1) }
    it { run_output.should =~ /The server does not support adding or removing members/ }

    context "with only owner" do
      let(:supports_members){ true }
      before{ with_mock_app.add_member(owner) }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should =~ /Bob  admin \(owner\)/ }
    end
  end
end
