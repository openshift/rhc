require 'spec_helper'
require 'rhc/commands/snapshot'
require 'rhc/config'
require 'uri'

describe RHC::Commands::Snapshot do

  before(:each) do
    FakeFS.activate!
    RHC::Config.set_defaults
  end

  describe 'run' do
    let(:arguments) { ['snapshot save', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p', 'password', '--app', 'mockapp'] }

    context 'when saving a snapshot' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        domain.add_application 'mockapp', 'mock-1.0'
      end
      it "should succeed" do
        expect { run }.should exit_with_code(0)
      end
    end

  end

  after(:each) do
    FakeFS::FileSystem.clear
    FakeFS.deactivate!
  end

end

