require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/snapshot'
require 'rhc/config'

describe RHC::Commands::Snapshot do

  before(:each) do
    #FakeFS.activate!
    RHC::Config.set_defaults
  end

  after(:each) do
    #FakeFS::FileSystem.clear
    #FakeFS.deactivate!
  end

  describe 'snapshot save' do
    let(:arguments) {['snapshot', 'save', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p', 'password', '--app', 'mockapp']}

    context 'when saving a snapshot' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
        uri = URI.parse app.ssh_url
        Kernel.should_receive(:`).with("ssh #{uri.user}@#{uri.host} 'snapshot' > #{app.name}.tar.gz")
      end
      it { expect { run }.should exit_with_code(0) }
    end

    context 'when failing to save a snapshot' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
      end
      it { expect { run }.should exit_with_code(130) }
    end

    context 'when saving a snapshot on windows' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
        RHC::Helpers.stub(:windows?) do ; true; end
        RHC::Helpers.stub(:jruby?) do ; false ; end
        RHC::Helpers.stub(:linux?) do ; false ; end
        uri = URI.parse app.ssh_url
        ssh = mock(Net::SSH)
        Net::SSH.should_receive(:start).with(uri.host, uri.user).and_yield(ssh)
        ssh.should_receive(:exec!).with("snapshot").and_yield(nil, :stdout, 'foo').and_yield(nil, :stderr, 'foo')
      end
      it { expect { run }.should exit_with_code(0) }
      it { run_output.should match("Success") }
    end

    context 'when timing out on windows' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
        RHC::Helpers.stub(:windows?) do ; true; end
        RHC::Helpers.stub(:jruby?) do ; false ; end
        RHC::Helpers.stub(:linux?) do ; false ; end
        uri = URI.parse app.ssh_url
        ssh = mock(Net::SSH)
        Net::SSH.should_receive(:start).with(uri.host, uri.user).and_raise(Timeout::Error)
      end
      it { expect { run }.should exit_with_code(130) }
    end

  end

  describe 'snapshot restore' do
    let(:arguments) {['snapshot', 'restore', '--noprompt', '-l', 'test@test.foo', '-p', 'password', '--app', 'mockapp']}

    context 'when restoring a snapshot' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
        uri = URI.parse app.ssh_url
        File.stub!(:exists?).and_return(true)
        RHC::TarGz.stub!(:contains).and_return(true)
        Kernel.should_receive(:`).with("cat #{app.name}.tar.gz | ssh #{uri.user}@#{uri.host} 'restore INCLUDE_GIT'")
      end
      it { expect { run }.should exit_with_code(0) }
    end

    context 'when restoring a snapshot on windows' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
        uri = URI.parse app.ssh_url
        RHC::Helpers.stub(:windows?) do ; true; end
        RHC::Helpers.stub(:jruby?) do ; false ; end
        RHC::Helpers.stub(:linux?) do ; false ; end
        ssh = mock(Net::SSH)
        session = mock(Net::SSH::Connection::Session)
        channel = mock(Net::SSH::Connection::Channel)
        Net::SSH.should_receive(:start).with(uri.host, uri.user).and_return(session)
        session.should_receive(:open_channel).and_yield(channel)
        channel.should_receive(:exec).with("restore").and_yield(nil, nil)
        channel.should_receive(:on_data).and_yield(nil, 'foo')
        channel.should_receive(:on_extended_data).and_yield(nil, nil, 'foo')
        channel.should_receive(:on_close).and_yield(nil)
        channel.should_receive(:send_data).with('foo')
        channel.should_receive(:eof!)
        session.should_receive(:loop)
      end
      it { expect { run }.should exit_with_code(0) }
    end

    context 'when timing out on windows' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
        RHC::Helpers.stub(:windows?) do ; true; end
        RHC::Helpers.stub(:jruby?) do ; false ; end
        RHC::Helpers.stub(:linux?) do ; false ; end
        uri = URI.parse app.ssh_url
        ssh = mock(Net::SSH)
        Net::SSH.should_receive(:start).with(uri.host, uri.user).and_raise(Timeout::Error)
      end
      it { expect { run }.should exit_with_code(130) }
    end

  end

end

