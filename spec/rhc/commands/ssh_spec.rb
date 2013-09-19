require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/ssh'

describe RHC::Commands::Ssh do
  let!(:rest_client){ MockRestClient.new }
  let!(:config){ user_config }
  before{ RHC::Config.stub(:home_dir).and_return('/home/mock_user') }
  before{ Kernel.stub(:exec).and_raise(RuntimeError) }

  describe 'ssh default' do
    context 'ssh' do
      let(:arguments) { ['ssh'] }
      it { run_output.should match('Usage:') }
    end
  end

  describe 'ssh without command' do
    let(:arguments) { ['app', 'ssh', 'app1'] }

    context 'when run' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        Kernel.should_receive(:exec).with("ssh", "fakeuuidfortestsapp1@127.0.0.1").and_return(0)
      end
      it { run_output.should match("Connecting to fakeuuidfortestsapp") }
      it { expect{ run }.to exit_with_code(0) }
    end
  end

  describe 'app ssh with command' do
    let(:arguments) { ['app', 'ssh', 'app1', 'ls', '/tmp'] }

    context 'when run' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        Kernel.should_receive(:exec).with("ssh", "fakeuuidfortestsapp1@127.0.0.1", "ls", "/tmp").and_return(0)
      end
      it { run_output.should_not match("Connecting to fakeuuidfortestsapp") }
      it { expect { run }.to exit_with_code(0) }
    end
  end

  describe 'app ssh with --gears' do
    before{ rest_client.add_domain("mockdomain").add_application("app1", "mock_type", true) }

    context 'with no command' do
      let(:arguments) { ['app', 'ssh', 'app1', '--gears'] }
      it('should display usage info') { run_output.should match("Usage:") }
      it { expect { run }.to exit_with_code(1) }
    end
    context 'with a command' do
      let(:arguments) { ['app', 'ssh', 'app1', '--gears', 'command', '--trace'] }
      before{ expect_multi_ssh('command', 'fakegearid0@fakesshurl.com' => 'foo', 'fakegearid1@fakesshurl.com' => 'bar') }
      it('should print the ssh output') { run_output.should == "[fakegearid0 ] foo\n[fakegearid1 ] bar\n\n" }
      it('should return successfully') { expect{ run }.to exit_with_code(0) }
    end
    context 'with an implicit app name' do
      before{ subject.class.any_instance.stub(:git_config_get){ |key| 'app1' if key == "rhc.app-name" } }
      let(:arguments) { ['app', 'ssh', '--gears', 'command', '--trace'] }
      before{ expect_multi_ssh('command', 'fakegearid0@fakesshurl.com' => 'foo', 'fakegearid1@fakesshurl.com' => 'bar') }
      it('should print the ssh output') { run_output.should == "[fakegearid0 ] foo\n[fakegearid1 ] bar\n\n" }
      it('should return successfully') { expect{ run }.to exit_with_code(0) }
    end
    context 'with an application id' do
      let(:arguments) { ['app', 'ssh', '--application-id', rest_client.domains.first.applications.first.id, '--gears', 'command', '--trace'] }
      before{ expect_multi_ssh('command', 'fakegearid0@fakesshurl.com' => 'foo', 'fakegearid1@fakesshurl.com' => 'bar') }
      it('should print the ssh output') { run_output.should == "[fakegearid0 ] foo\n[fakegearid1 ] bar\n\n" }
      it('should return successfully') { expect{ run }.to exit_with_code(0) }
    end
    context 'with --raw' do
      let(:arguments) { ['app', 'ssh', 'app1', '--gears', 'command', '--raw'] }
      before{ expect_multi_ssh('command', 'fakegearid0@fakesshurl.com' => 'foo', 'fakegearid1@fakesshurl.com' => 'bar') }
      it('should print the ssh output') { run_output.should == "foo\nbar\n\n" }
    end
    context 'with --limit' do
      let(:arguments) { ['app', 'ssh', 'app1', '--gears', 'command', '--limit', '1'] }
      before{ expect_multi_ssh('command', 'fakegearid0@fakesshurl.com' => 'foo', 'fakegearid1@fakesshurl.com' => 'bar') }
      it('should print the ssh output') { run_output.should == "[fakegearid0 ] foo\n[fakegearid1 ] bar\n\n" }
    end
    context 'with invalid --limit value' do
      ['0','-10'].each do |value|
        let(:arguments) { ['app', 'ssh', 'app1', '--gears', 'command', '--limit', value] }
        it { run_output.should match('--limit must be an integer greater than zero') }
      end
    end
    context 'with multiline output and --always-prefix' do
      let(:arguments) { ['app', 'ssh', 'app1', '--gears', 'command', '--always-prefix'] }
      before{ expect_multi_ssh('command', 'fakegearid0@fakesshurl.com' => "foo\ntest", 'fakegearid1@fakesshurl.com' => "bar\ntest") }
      it('should print the ssh output') { run_output.should == "[fakegearid0 ] foo\n[fakegearid0 ] test\n[fakegearid1 ] bar\n[fakegearid1 ] test\n\n" }
    end
    context 'with multiline output' do
      let(:arguments) { ['app', 'ssh', 'app1', '--gears', 'command'] }
      before{ expect_multi_ssh('command', 'fakegearid0@fakesshurl.com' => "foo\ntest", 'fakegearid1@fakesshurl.com' => "bar\ntest") }
      it('should print the ssh output') { run_output.should == "=== fakegearid0 \nfoo\ntest\n=== fakegearid1 \nbar\ntest\n\n" }
    end
  end

  describe 'app ssh no system ssh' do
    let(:arguments) { ['app', 'ssh', 'app1'] }

    context 'when run' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        RHC::Commands::Ssh.any_instance.should_receive(:has_ssh?).and_return(false)
      end
      it { run_output.should match("Please use the --ssh option to specify the path to your SSH executable, or install SSH.") }
      it { expect { run }.to exit_with_code(1) }
    end
  end

  describe 'app ssh custom ssh' do
    let(:arguments) { ['app', 'ssh', 'app1', '--ssh', 'path_to_ssh'] }

    context 'when custom ssh does not exist' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        RHC::Commands::Ssh.any_instance.should_not_receive(:has_ssh?)
        File.should_receive(:exist?).with("path_to_ssh").once.and_return(false)
      end
      it { run_output.should match("SSH executable 'path_to_ssh' does not exist.") }
      it { expect { run }.to exit_with_code(1) }
    end

    context 'when custom ssh is not executable' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        RHC::Commands::Ssh.any_instance.should_not_receive(:has_ssh?)
        File.should_receive(:exist?).with("path_to_ssh").once.and_return(true)
        File.should_receive(:executable?).with("path_to_ssh").once.and_return(false)
      end
      it { run_output.should match("SSH executable 'path_to_ssh' is not executable.") }
      it { expect { run }.to exit_with_code(1) }
    end

    context 'when custom ssh exists' do
      before(:each) do
        @domain = rest_client.add_domain("mockdomain")
        @domain.add_application("app1", "mock_type")
        RHC::Commands::Ssh.any_instance.should_not_receive(:has_ssh?)
        File.should_receive(:exist?).with("path_to_ssh").once.and_return(true)
        File.should_receive(:executable?).with("path_to_ssh").once.and_return(true)
        Kernel.should_receive(:exec).with("path_to_ssh", "fakeuuidfortestsapp1@127.0.0.1").once.times.and_return(0)
      end
      it { run_output.should match("Connecting to fakeuuidfortestsapp") }
      it { expect { run }.to exit_with_code(0) }
    end
  end

  describe 'ssh tests' do
    let(:arguments) { ['app', 'ssh', 'app1', '-s /bin/blah'] }

    context 'has_ssh?' do
      before{ RHC::Commands::Ssh.any_instance.stub(:ssh_version){ raise "Fake Exception" } }
      its(:has_ssh?) { should be_false }
    end
  end
end
