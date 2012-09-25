require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/snapshot'
require 'rhc/config'

describe RHC::Commands::Snapshot do

  APP_NAME = 'mockapp'

  before(:each) do
    RHC::Config.set_defaults
    @rc = MockRestClient.new
    @app = @rc.add_domain("mockdomain").add_application APP_NAME, 'mock-1.0'
    @ssh_uri = URI.parse @app.ssh_url
    filename = APP_NAME + '.tar.gz'
    FileUtils.cp(File.expand_path('../../assets/targz_sample.tar.gz', __FILE__), filename)
  end

  after(:each) do
    filename = APP_NAME + '.tar.gz'
    File.delete filename if File.exist? filename
  end

  describe 'snapshot save' do
    let(:arguments) {['snapshot', 'save', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p', 'password', '--app', 'mockapp']}

    context 'when saving a snapshot' do
      before(:each) do
        Kernel.should_receive(:`).with("ssh #{@ssh_uri.user}@#{@ssh_uri.host} 'snapshot' > #{@app.name}.tar.gz")
      end
      it { expect { run }.should exit_with_code(0) }
    end

    context 'when failing to save a snapshot' do
      before(:each) do
        Kernel.should_receive(:`).with("ssh #{@ssh_uri.user}@#{@ssh_uri.host} 'snapshot' > #{@app.name}.tar.gz")
        $?.stub(:exitstatus) { 1 }
      end
      it { expect { run }.should exit_with_code(130) }
    end

    context 'when saving a snapshot on windows' do
      before(:each) do
        RHC::Helpers.stub(:windows?) do ; true; end
        RHC::Helpers.stub(:jruby?) do ; false ; end
        RHC::Helpers.stub(:linux?) do ; false ; end
        ssh = mock(Net::SSH)
        Net::SSH.should_receive(:start).with(@ssh_uri.host, @ssh_uri.user).and_yield(ssh)
        ssh.should_receive(:exec!).with("snapshot").and_yield(nil, :stdout, 'foo').and_yield(nil, :stderr, 'foo')
      end
      it { expect { run }.should exit_with_code(0) }
      it { run_output.should match("Success") }
    end

    context 'when timing out on windows' do
      before(:each) do
        RHC::Helpers.stub(:windows?) do ; true; end
        RHC::Helpers.stub(:jruby?) do ; false ; end
        RHC::Helpers.stub(:linux?) do ; false ; end
        ssh = mock(Net::SSH)
        Net::SSH.should_receive(:start).with(@ssh_uri.host, @ssh_uri.user).and_raise(Timeout::Error)
      end
      it { expect { run }.should exit_with_code(130) }
    end

  end

  describe 'snapshot restore' do
    let(:arguments) {['snapshot', 'restore', '--noprompt', '-l', 'test@test.foo', '-p', 'password', '--app', 'mockapp']}

    context 'when restoring a snapshot' do
      before(:each) do
        File.stub!(:exists?).and_return(true)
        RHC::TarGz.stub!(:contains).and_return(true)
        Kernel.should_receive(:`).with("cat #{@app.name}.tar.gz | ssh #{@ssh_uri.user}@#{@ssh_uri.host} 'restore INCLUDE_GIT'")
      end
      it { expect { run }.should exit_with_code(0) }
    end

    context 'when restoring a snapshot on windows' do
      before(:each) do
        RHC::Helpers.stub(:windows?) do ; true; end
        RHC::Helpers.stub(:jruby?) do ; false ; end
        RHC::Helpers.stub(:linux?) do ; false ; end
        ssh = mock(Net::SSH)
        session = mock(Net::SSH::Connection::Session)
        channel = mock(Net::SSH::Connection::Channel)
        Net::SSH.should_receive(:start).with(@ssh_uri.host, @ssh_uri.user).and_return(session)
        session.should_receive(:open_channel).and_yield(channel)
        channel.should_receive(:exec).with("restore").and_yield(nil, nil)
        channel.should_receive(:on_data).and_yield(nil, 'foo')
        channel.should_receive(:on_extended_data).and_yield(nil, nil, 'foo')
        channel.should_receive(:on_close).and_yield(nil)
        lines = ''
        File.open(File.expand_path('../../assets/targz_sample.tar.gz', __FILE__), 'rb') do |file|
          file.chunk(1024) do |chunk|
            lines << chunk
          end
        end
        channel.should_receive(:send_data).with(lines)
        channel.should_receive(:eof!)
        session.should_receive(:loop)
      end
      it { expect { run }.should exit_with_code(0) }
    end

    context 'when timing out on windows' do
      before(:each) do
        RHC::Helpers.stub(:windows?) do ; true; end
        RHC::Helpers.stub(:jruby?) do ; false ; end
        RHC::Helpers.stub(:linux?) do ; false ; end
        ssh = mock(Net::SSH)
        Net::SSH.should_receive(:start).with(@ssh_uri.host, @ssh_uri.user).and_raise(Timeout::Error)
      end
      it { expect { run }.should exit_with_code(130) }
    end

  end

end

