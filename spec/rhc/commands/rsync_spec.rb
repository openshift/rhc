require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/rsync'

describe RHC::Commands::Rsync do
  let!(:rest_client){ MockRestClient.new }
  let!(:config){ user_config }
  before{ RHC::Config.stub(:home_dir).and_return('/home/mock_user') }
  before{ Kernel.stub(:exec).and_raise(RuntimeError) }

  describe 'rsync default' do
    context 'rsync' do
      let(:arguments) { ['rsync'] }
      it { run_output.should match('Usage:') }
    end
  end

  describe 'rsync with invalid option' do
    let (:arguments) {['app', 'rsync', 'app1', 'invalid_command', 'file.txt', 'app-root/data']}

    context 'when run' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
      end
      it { run_output.should match("'invalid_command' is not a valid argument for this command.  Please use upload or download.") }
    end
  end

  describe 'local file or path does not exist' do
    let (:arguments) {['app', 'rsync', 'app1', 'upload', 'file.txt', 'app-root/data']}

    context 'when run' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        File.should_receive(:exist?).with("file.txt").once.and_return(false)
      end
      it { run_output.should match("Local file, file_path, or directory could not be found.") }
    end
  end

  describe 'app rsync no system rsync' do
    let(:arguments) { ['app', 'rsync', 'app1', 'upload', 'test.txt', 'app-root/data'] }

    context 'when run' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        RHC::Commands::Rsync.any_instance.should_receive(:has_rsync?).and_return(false)
      end
      it { run_output.should match("No system rsync available. Please use the --rsync option to specify the path to your rsync executable, or install rsync.") }
      it { expect { run }.to exit_with_code(1) }
    end
  end

  describe 'app rsync custom rsync' do
    let(:arguments) { ['app', 'rsync', 'app1', 'upload', 'test.txt', 'app-root/data', '--rsync', 'path_to_rsync'] }

    context 'when custom rsync does not exist' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        RHC::Commands::Rsync.any_instance.should_not_receive(:has_rsync?)
        File.should_receive(:exist?).with("path_to_rsync").once.and_return(false)
      end
      it { run_output.should match("rsync executable 'path_to_rsync' does not exist.") }
      it { expect { run }.to exit_with_code(1) }
    end

    context 'when custom rsync is not executable' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        RHC::Commands::Rsync.any_instance.should_not_receive(:has_rsync?)
        File.should_receive(:exist?).with("path_to_rsync").once.and_return(true)
        File.should_receive(:executable?).with(/.*path_to_rsync/).at_least(1).and_return(false)
      end
      it { run_output.should match("rsync executable 'path_to_rsync' is not executable.") }
      it { expect { run }.to exit_with_code(1) }
    end

    context 'when custom rsync exists' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        RHC::Commands::Rsync.any_instance.should_not_receive(:has_rsync?)
        File.should_receive(:exist?).with("test.txt").once.and_return(true)
        File.should_receive(:exist?).with( "path_to_rsync").once.and_return(true)
        File.should_receive(:executable?).with( "path_to_rsync").once.and_return(true)
        Kernel.should_receive(:exec).with("path_to_rsync","-avzr","test.txt", "fakeuuidfortestsapp1@127.0.0.1:app-root/data").once.times.and_return(0)
      end
      it { run_output.should match("Synchronizing files with fakeuuidfortestsapp1@127.0.0.1") }
      it { expect { run }.to exit_with_code(0) }
    end
  end

  describe 'rsync tests' do
    let(:arguments) { ['app', 'rsync', 'app1', 'upload', 'test.txt', 'app-root/data', '-s /bin/blah'] }

    context 'has_rsync?' do
      before{ RHC::Commands::Rsync.any_instance.stub(:rsync_version){ raise "Fake Exception" } }
      its(:has_rsync?) { should be_false }
    end
  end

end
