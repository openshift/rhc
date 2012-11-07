require 'spec_helper'
require 'rhc/commands/port-forward'
require 'rhc/config'
require 'uri'

describe RHC::Commands::PortForward do

  before(:each) do
    RHC::Config.set_defaults
  end

  describe 'run' do
    let(:arguments) { ['port-forward', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p', 'password', '--app', 'mockapp'] }

    context 'when port forwarding a scaled app' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        domain.add_application 'mockapp', 'mock-1.0', true
      end
#     it "should error out" do
#        expect { run }.should exit_with_code(128)
#      end
#      it "should match the app state" do
#        @rc.domains[0].id.should == 'mockdomain'
#        @rc.domains[0].applications.size.should == 1
#        @rc.domains[0].applications[0].name.should == 'mockapp'
#      end
#      it { run_output.should match("This utility does not currently support scaled applications. You will need to set up port forwarding manually.") }
    end

    context 'when port forwarding an app without ports to forward' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
        uri = URI.parse app.ssh_url
        ssh = mock(Net::SSH)
        Net::SSH.should_receive(:start).with(uri.host, uri.user).and_yield(ssh)
        ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stderr, '127.0.0.1:3306')
      end
      it "should error out as no ports to forward" do
        expect { run }.should exit_with_code(102)
        @rc.domains[0].id.should == 'mockdomain'
        @rc.domains[0].applications.size.should == 1
        @rc.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should match("no available ports to forward.") }
    end

    context 'when port forwarding an app with permission denied ports' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
        ssh = mock(Net::SSH)
        uri = URI.parse app.ssh_url
        Net::SSH.should_receive(:start).with(uri.host, uri.user).and_yield(ssh)
        ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stderr, 'permission denied')
      end
      it "should error out as permission denied" do
        expect { run }.should exit_with_code(129)
        @rc.domains[0].id.should == 'mockdomain'
        @rc.domains[0].applications.size.should == 1
        @rc.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should match("Permission denied") }
    end

    context 'when port forwarding an app with ports to forward' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
        ssh = mock(Net::SSH)
        uri = URI.parse app.ssh_url
        Net::SSH.should_receive(:start).with(uri.host, uri.user).and_yield(ssh).twice
        ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stdout, '127.0.0.1:3306')
        forward = mock(Net::SSH::Service::Forward)
        ssh.should_receive(:forward).and_return(forward)
        forward.should_receive(:local).with('127.0.0.1', 3306, '127.0.0.1', 3306)
        ssh.should_receive(:loop)
      end
      it "should error out as no ports to forward" do
        expect { run }.should exit_with_code(0)
        @rc.domains[0].id.should == 'mockdomain'
        @rc.domains[0].applications.size.should == 1
        @rc.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should include("Forwarding ports, use ctl + c to stop") }
    end

    context 'when port forwarding an app with ports to forward' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
      end
      it "should error out if ssh host is unreachable" do
        expect { run }.should exit_with_code(1)
        @rc.domains[0].id.should == 'mockdomain'
        @rc.domains[0].applications.size.should == 1
        @rc.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should include("Error trying to forward ports.") }
    end

    context 'when port forwarding an app with ports to forward' do
      before(:each) do
        @rc = MockRestClient.new
        domain = @rc.add_domain("mockdomain")
        app = domain.add_application 'mockapp', 'mock-1.0'
        ssh = mock(Net::SSH)
        uri = URI.parse app.ssh_url
        Net::SSH.should_receive(:start).with(uri.host, uri.user).and_yield(ssh).twice
        ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stdout, '127.0.0.1:3306')
        forward = mock(Net::SSH::Service::Forward)
        ssh.should_receive(:forward).and_return(forward)
        forward.should_receive(:local).with('127.0.0.1', 3306, '127.0.0.1', 3306)
        ssh.should_receive(:loop).and_raise(Interrupt.new)
      end
      it "should exit when user interrupts" do
        expect { run }.should exit_with_code(0)
        @rc.domains[0].id.should == 'mockdomain'
        @rc.domains[0].applications.size.should == 1
        @rc.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should include("Ending port forward") }
    end

   end
end

