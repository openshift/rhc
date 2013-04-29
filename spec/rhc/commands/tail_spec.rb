require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/tail'
require 'rhc/config'

describe RHC::Commands::Tail do
  let!(:rest_client) { MockRestClient.new }
  before(:each) do
    user_config
    domain = rest_client.add_domain("mock-domain-0")
    @app = domain.add_application("mock-app-0", "ruby-1.8.7")
    @app.stub(:ssh_url).and_return("ssh://user@test.domain.com")
  end

  describe 'help' do
    let(:arguments) { ['tail', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc tail") }
    end
  end

  describe 'tail' do
    let(:arguments) { ['tail', 'mock-app-0'] }

    context 'when ssh connects' do
      before (:each) {Net::SSH.should_receive(:start).with('test.domain.com', 'user') }
      it { expect { run }.to exit_with_code(0) }
    end

    context 'is run on an unreachable domain' do
      before (:each) {Net::SSH.should_receive(:start).and_raise(SocketError) }
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /The connection to test.domain.com failed: / }
    end

    context 'is refused' do
      before (:each) {Net::SSH.should_receive(:start).and_raise(Errno::ECONNREFUSED) }
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /The server test.domain.com refused a connection with user user/ }
    end

    context 'succeeds and exits on Interrupt' do
      before (:each) { rest_client.stub(:find_domain) { raise Interrupt } }
      it { expect { run }.to raise_error(Interrupt) }
    end

    context 'succeeds when a gear is specified' do
      before (:each) {Net::SSH.should_receive(:start).with('fakesshurl.com', 'fakegearid') }
      let(:arguments) { ['tail', 'mock-app-0', '--gear', 'fakegearid' ] }

      it { expect { run }.to exit_with_code(0) }
    end

    context 'fails when an invalid gear is specified' do
      let(:arguments) { ['tail', 'mock-app-0', '--gear', 'gearthatdoesnotexist' ] }

      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /Gear gearthatdoesnotexist not found/ }
    end

    context 'fails when a gear with no ssh info is specified' do
      let(:arguments) { ['tail', 'mock-app-0', '--gear', 'fakegearid' ] }

      # Given - gears in gear group should not have ssh info
      before(:each) do
        gg = MockRestGearGroup.new(rest_client)
        @app.stub(:gear_groups).and_return([gg])
        gg.stub(:gears).and_return([{'state' => 'started', 'id' => 'fakegearid'}])
      end

      it { expect { run }.to exit_with_code(1) }
      it { run_output.should =~ /The server does not support per gear operations/ }
    end

  end
end
