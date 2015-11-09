require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/port_forward'

describe RHC::Commands::PortForward do

  let!(:rest_client){ MockRestClient.new }
  before{ user_config }

  describe 'run' do
    let(:arguments) { ['port-forward', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p', 'password', '--app', 'mockapp'] }

    before :each do
      @domain = rest_client.add_domain("mockdomain")
      @app = @domain.add_application 'mockapp', 'mock-1.0'
      @uri = URI.parse @app.ssh_url
      @ssh = double(Net::SSH)
    end

    context 'when port forwarding for a down appl' do
      before(:each) do
        Net::SSH.should_receive(:start).with(@uri.host, @uri.user).and_yield(@ssh)
        @ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stderr, '127.0.0.1:3306')
        @gg = MockRestGearGroup.new(rest_client)
        @app.should_receive(:gear_groups).and_return([@gg])
        @gg.should_receive(:gears).and_return([{'state' => 'stopped', 'id' => 'fakegearid'}])
      end
      it "should error out and suggest restarting the application" do
        expect { run }.to exit_with_code(1)
      end
      it { run_output.should match(/none.*The application is stopped\..*restart/m) }
    end

    context 'when port forwarding an app without ports to forward' do
      before(:each) do
        Net::SSH.should_receive(:start).with(@uri.host, @uri.user).and_yield(@ssh)
        @ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stderr, '127.0.0.1:3306')
      end
      it "should error out as no ports to forward" do
        expect { run }.to exit_with_code(102)
        rest_client.domains[0].name.should == 'mockdomain'
        rest_client.domains[0].applications.size.should == 1
        rest_client.domains[0].applications[0].name.should == 'mockapp'
      end
      it("should report no ports") { run_output.should match("no available ports to forward.") }
    end

    context 'when port forwarding an app with permission denied ports' do
      before(:each) do
        Net::SSH.should_receive(:start).with(@uri.host, @uri.user).and_yield(@ssh)
        @ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stderr, 'permission denied')
      end
      it "should error out as permission denied" do
        expect { run }.to exit_with_code(129)
        rest_client.domains[0].name.should == 'mockdomain'
        rest_client.domains[0].applications.size.should == 1
        rest_client.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should match("Permission denied") }
    end

    context 'when port forwarding an app with ports to forward' do
      before(:each) do
        Net::SSH.should_receive(:start).with(@uri.host, @uri.user).and_yield(@ssh).twice
        @ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stderr, 'mysql -> 127.0.0.1:3306')
        forward = double(Net::SSH::Service::Forward)
        @ssh.should_receive(:forward).and_return(forward)
        forward.should_receive(:local).with(3306, '127.0.0.1', 3306)
        @ssh.should_receive(:loop)
      end
      it "should run successfully" do
        expect { run }.to exit_with_code(0)
        rest_client.domains[0].name.should == 'mockdomain'
        rest_client.domains[0].applications.size.should == 1
        rest_client.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should match(/Forwarding ports.*Press CTRL-C/m) }
    end

    context 'when host is unreachable' do
      before(:each) do
        Net::SSH.should_receive(:start).and_raise(Errno::EHOSTUNREACH)
      end
      it "should error out" do
        expect { run }.to exit_with_code(1)
        rest_client.domains[0].name.should == 'mockdomain'
        rest_client.domains[0].applications.size.should == 1
        rest_client.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should include("Error trying to forward ports.") }
    end

    context 'when REST client connection times out' do
      before(:each) do
        rest_client.should_receive(:find_domain).and_raise(RHC::Rest::ConnectionException)
      end
      it("should error out") { expect { run }.to exit_with_code(1) }
      it{ run_output.should match("Connection.*failed:") }
    end

    context 'when port forwarding an app with ports to forward' do
      before(:each) do
        Net::SSH.should_receive(:start).with(@uri.host, @uri.user).and_yield(@ssh).twice
        @ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stderr, 'mysql -> 127.0.0.1:3306')
        forward = double(Net::SSH::Service::Forward)
        @ssh.should_receive(:forward).and_return(forward)
        forward.should_receive(:local).with(3306, '127.0.0.1', 3306)
        @ssh.should_receive(:loop).and_raise(Interrupt.new)
      end
      it "should exit when user interrupts" do
        expect { run }.to exit_with_code(0)
        rest_client.domains[0].name.should == 'mockdomain'
        rest_client.domains[0].applications.size.should == 1
        rest_client.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should include("Ending port forward") }
    end

    context 'when local port is already bound' do
      before(:each) do
        Net::SSH.should_receive(:start).with(@uri.host, @uri.user).and_yield(@ssh).twice
        @ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stderr, 'mysql -> 127.0.0.1:3306')
        forward = double(Net::SSH::Service::Forward)
        @ssh.should_receive(:forward).at_least(2).and_return(forward)
        forward.should_receive(:local).with(3306, '127.0.0.1', 3306).and_raise(Errno::EACCES)
        forward.should_receive(:local).with(3307, '127.0.0.1', 3306)
        @ssh.should_receive(:loop).and_raise(Interrupt.new)
      end
      it 'should bind to a higher port' do
        run_output.should include("3307")
      end
    end

    # Windows 7 reportedly returns EPERM rather than EACCES when the
    # port is in use by a local service (see
    # <https://bugzilla.redhat.com/show_bug.cgi?id=1125963>).
    context 'when local port is in use by local service on Windows 7' do
      before(:each) do
        Net::SSH.should_receive(:start).with(@uri.host, @uri.user).and_yield(@ssh).twice
        @ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stderr, 'mysql -> 127.0.0.1:3306')
        forward = double(Net::SSH::Service::Forward)
        @ssh.should_receive(:forward).at_least(2).and_return(forward)
        forward.should_receive(:local).with(3306, '127.0.0.1', 3306).and_raise(Errno::EPERM)
        forward.should_receive(:local).with(3307, '127.0.0.1', 3306)
        @ssh.should_receive(:loop).and_raise(Interrupt.new)
      end
      it 'should bind to a higher port' do
        run_output.should include("3307")
      end
    end

    context 'when host refuses connection' do
      before(:each) do
        Net::SSH.should_receive(:start).with(@uri.host, @uri.user).and_yield(@ssh).twice
        @ssh.should_receive(:exec!).with("rhc-list-ports").and_yield(nil, :stderr, 'mysql -> 127.0.0.1:3306')
        forward = double(Net::SSH::Service::Forward)
        @ssh.should_receive(:forward).and_raise(Errno::ECONNREFUSED)
      end
      it "should error out" do
        expect { run }.to exit_with_code(0)
      end
      it { run_output.should include("ssh -N") }
      it { run_output.should include("Error forwarding") }
    end

    context 'when port forwarding a scaled app with ports to forward' do
      let(:haproxy_host_1) { '127.0.0.1' }
      let(:haproxy_host_2) { '127.0.0.2' }
      let(:mongo_host) { '51125bb94a-test907742.dev.rhcloud.com' }
      let(:ipv6_host) { '::1' }
      before(:each) do
        Net::SSH.should_receive(:start).with(@uri.host, @uri.user).and_yield(@ssh).twice
        @ssh.should_receive(:exec!).with("rhc-list-ports").
          and_yield(nil, :stderr, "httpd -> #{haproxy_host_1}:8080\nhttpd -> #{haproxy_host_2}:8080\nmongodb -> #{mongo_host}:35541\nmysqld -> #{ipv6_host}:3306")
        forward = double(Net::SSH::Service::Forward)
        @ssh.should_receive(:forward).at_least(3).times.and_return(forward)
        forward.should_receive(:local).with(8080, haproxy_host_1, 8080)
        forward.should_receive(:local).with(8080, haproxy_host_2, 8080).and_raise(Errno::EADDRINUSE)
        forward.should_receive(:local).with(8081, haproxy_host_2, 8080)
        forward.should_receive(:local).with(35541, mongo_host, 35541)
        forward.should_receive(:local).with(3306, ipv6_host, 3306)
        @ssh.should_receive(:loop).and_raise(Interrupt.new)
      end
      it "should exit when user interrupts" do
        expect { run }.to exit_with_code(0)
        rest_client.domains[0].name.should == 'mockdomain'
        rest_client.domains[0].applications.size.should == 1
        rest_client.domains[0].applications[0].name.should == 'mockapp'
      end
      it { run_output.should include("Ending port forward") }
    end

    context 'when port forwarding a single gear on a scaled app' do
      let(:gear_host) { 'fakesshurl.com' }
      let(:gear_user) { 'fakegearid0' }
      let(:arguments) { ['port-forward', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p', 'password', '--app', 'mockapp', '--gear', @gear_id] }

      it 'should run successfully' do
        @gear_id = 'fakegearid0'
        Net::SSH.should_receive(:start).with(gear_host, gear_user).and_yield(@ssh).twice

        @ssh.should_receive(:exec!).with("rhc-list-ports --exclude-remote").
          and_yield(nil, :stderr, "mongodb -> #{gear_host}:35541")
        forward = double(Net::SSH::Service::Forward)
        @ssh.should_receive(:forward).and_return(forward)
        forward.should_receive(:local).with(35541, gear_host, 35541)
        @ssh.should_receive(:loop).and_raise(Interrupt.new)

        expect { run }.to exit_with_code(0)
      end

      it 'should fail if the specified gear is missing' do
        @gear_id = 'notarealgearxxxxx'

        expect { run }.to exit_with_code(1)
        run_output.should include('Gear notarealgearxxxxx not found')
      end

      it 'should fail if the specified gear has no ssh info' do
        @gear_id = 'fakegearid0'

        # Given - gears in gear group should not have ssh info
        gg = MockRestGearGroup.new(rest_client)
        @app.stub(:gear_groups).and_return([gg])
        gg.stub(:gears).and_return([{'state' => 'started', 'id' => 'fakegearid0'}])

        expect { run }.to exit_with_code(1)
        run_output.should match('The server does not support operations on individual gears.')
      end

    end

    context 'when port forwarding with a custom ssh executable' do
      ssh_path = '/usr/bin/ssh'
      before(:each) do
        base_config { |c, d| d.add 'ssh', ssh_path }
      end

      it 'should use the executable to check for ports' do
        subject.class.any_instance.should_receive(:exec).with("#{ssh_path} #{@uri.user}@#{@uri.host} 'rhc-list-ports 2>&1'").
          and_return([0, 'httpd -> 127.1.244.1:8080'])
        expect { run }.to exit_with_code(1)
        expect { run_output.should match(/You can try forwarding.*rhc-list-ports.*/) }
      end

      it 'should exit when ssh command fails to collect ports' do
        subject.class.any_instance.should_receive(:exec).with("#{ssh_path} #{@uri.user}@#{@uri.host} 'rhc-list-ports 2>&1'").
          and_return([1, 'some ssh error'])
        expect { run }.to exit_with_code(133)
        expect { run_output.should match(/some ssh error/) }
      end
    end

  end
end

