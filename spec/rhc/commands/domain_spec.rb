require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/domain'
require 'rhc/config'

describe RHC::Commands::Domain do
  before(:each) do
    RHC::Config.set_defaults
  end

  describe 'run' do
    let(:arguments) { ['domain', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run with no domains' do
      before(:each) do
        @rc = MockRestClient.new
      end
      it { expect { run }.should exit_with_code(0) }
      it { run_output.should match("Namespace: No namespaces found") }
    end

    context 'when run with one domain no apps' do
      before(:each) do
        @rc = MockRestClient.new
        @rc.add_domain("onedomain")
      end
      it { expect { run }.should exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("Namespace onedomain's Applications")
        output.should match("No applications found")
      end
    end

    context 'when run with multiple domain no apps' do
      before(:each) do
        @rc = MockRestClient.new
        @rc.add_domain("firstdomain")
        @rc.add_domain("seconddomain")
      end
      it { expect { run }.should exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("Namespace\\(0\\): firstdomain")
        output.should match("Namespace\\(1\\): seconddomain")
        output.should match("Namespace firstdomain's Applications")
        output.should match("Namespace seconddomain's Applications")
      end
    end

    context 'when run with one domain multiple apps' do
      before(:each) do
        @rc = MockRestClient.new
        d = @rc.add_domain("appdomain")
        a = d.add_application("app_no_carts", "testframework-1.0")
        a = d.add_application("app_multi_carts", "testframework-1.0")
        a.add_cartridge("testcart-1")
        a.add_cartridge("testcart-2")
        a.add_cartridge("testcart-3")
      end
      it { expect { run }.should exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("app_no_carts")
        output.should match("None")
        output.should match("app_multi_carts")
        output.should match("testframework-1.0")
        output.should match("testcart-1")
        output.should match("testcart-2")
        output.should match("testcart-3")
      end
    end
  end

  describe 'create' do
    let(:arguments) { ['domain', 'create', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'testnamespace'] }

    context 'when no issues with ' do
      before(:each) do
        @rc = MockRestClient.new
      end

      it "should create a domain" do
        expect { run }.should exit_with_code(0)
        @rc.domains[0].id.should == 'testnamespace'
      end
      it { run_output.should match(/'testnamespace'\n\nRESULT:\n.*Success/m) }
    end
  end

  describe 'update' do
    let(:arguments) { ['domain', 'update', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'alterednamespace'] }

    context 'when no issues with ' do
      before(:each) do
        @rc = MockRestClient.new
        @rc.add_domain("olddomain")
      end

      it "should update a domain" do
        expect { run }.should exit_with_code(0)
        @rc.domains[0].id.should == 'alterednamespace'
      end
      it { run_output.should match(/Updating domain 'olddomain' to namespace 'alterednamespace'\n\nRESULT:\n.*Success/m) }
    end

    context 'when there is no domain' do
      before(:each) do
        @rc = MockRestClient.new
      end

      it "should not create a domain" do
        expect { run }.should exit_with_code(127)
        @rc.domains.empty?.should be_true
      end
      it { run_output.should match("No domains are registered to the user test@test.foo") }
    end
  end

  describe 'alter alias' do
    let(:arguments) { ['domain', 'alter', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'alterednamespace'] }

    context 'when no issues with ' do
      before(:each) do
        @rc = MockRestClient.new
        @rc.add_domain("olddomain")
      end

      it "should update a domain" do
        expect { run }.should exit_with_code(0)
        @rc.domains[0].id.should == 'alterednamespace'
      end
      it { run_output.should match(/Updating domain 'olddomain' to namespace 'alterednamespace'\n\nRESULT:\n.*Success/m) }
    end
  end

  describe 'delete' do
    let(:arguments) { ['domain', 'delete', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'deleteme'] }

    context 'when no issues with ' do
      before(:each) do
        @rc = MockRestClient.new
        @rc.add_domain("deleteme")
      end

      it "should delete a domain" do
        expect { run }.should exit_with_code(0)
        @rc.domains.empty?.should be_true
      end
    end

    context 'when there is a different domain' do
      before(:each) do
        @rc = MockRestClient.new
        @rc.add_domain("dontdelete")
      end

      it "should error out" do
        expect { run }.should exit_with_code(127)
        @rc.domains[0].id.should == 'dontdelete'
      end
      it { run_output.should match("Domain deleteme does not exist") }
    end
  end

  describe 'alias destroy' do
    let(:arguments) { ['domain', 'destroy', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'deleteme'] }

    context 'when no issues with ' do
      before(:each) do
        @rc = MockRestClient.new
        @rc.add_domain("deleteme")
      end

      it "should delete a domain" do
        expect { run }.should exit_with_code(0)
        @rc.domains.empty?.should be_true
      end
    end
  end

  describe 'status' do
    let(:arguments) { ['domain', 'status', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    before(:each) do
      Kernel.stub!(:system) do |cmd| 
        @cmd = cmd
        # run the true command to get $?.exitstatus == 0
        system("true")
      end
    end

    context 'rhc-chk should be executed' do
      it "runs" do 
        expect { run }.should exit_with_code(0)
        # check lengths here because different versions of ruby output the switches in different order
        @cmd.length.should == "rhc-chk --noprompt true --config test.conf --rhlogin test@test.foo --password password 2>&1".length
      end
    end
  end

  describe 'help' do
    let(:arguments) { ['domain', 'help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.should exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc domain") }
    end
  end
end
