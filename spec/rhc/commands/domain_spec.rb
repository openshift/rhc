require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/domain'

describe RHC::Commands::Domain do
  let!(:rest_client){ MockRestClient.new }
  before{ user_config }

  describe 'default action' do
    context 'when run with no domains' do
      let(:arguments) { ['domain', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

      it { expect { run }.should exit_with_code(1) }
      it { run_output.should match(/In order to deploy applications.*rhc domain create/) }
    end
    context 'when help is shown' do
      let(:arguments) { ['domain', '--noprompt', '--help'] }

      it { expect { run }.should exit_with_code(0) }
      it { run_output.should match(/The default action for this resource is 'show'/) }
    end
  end

  describe 'show' do
    let(:arguments) { ['domain', 'show', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run with no domains' do
      it { expect { run }.should exit_with_code(1) }
      it { run_output.should match(/In order to deploy applications.*rhc domain create/) }
    end

    context 'when run with one domain no apps' do
      before{ rest_client.add_domain("onedomain") }

      it { expect { run }.should exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("The domain onedomain exists but has no applications. You can use")
      end
    end

    context 'when run with multiple domain no apps' do
      before(:each) do
        rest_client.add_domain("firstdomain")
        rest_client.add_domain("seconddomain")
      end
      it { expect { run }.should exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("The domain firstdomain exists but has no applications. You can use")
        output.should_not match("Applications in seconddomain")
      end
    end

    context 'when run with one domain multiple apps' do
      before(:each) do
        d = rest_client.add_domain("appdomain")
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
        output.should match("app_multi_carts")
        output.should match("testframework-1.0")
        output.should match("testcart-1")
        output.should match("testcart-2")
        output.should match("testcart-3")
      end
    end

    context 'when run with an app without cartridges' do
      before(:each) do
        d = rest_client.add_domain("appdomain")
        a = d.add_application("app_no_carts")
      end
      it { expect { run }.should exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("app_no_carts")
        output.should match(/127.0.0.1\s*$/m)
      end
    end
  end

  describe 'create' do
    let(:arguments) { ['domain', 'create', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'testnamespace'] }

    context 'when no issues with ' do

      it "should create a domain" do
        expect { run }.should exit_with_code(0)
        rest_client.domains[0].id.should == 'testnamespace'
      end
      it { run_output.should match(/'testnamespace'.*?RESULT:.*?Success/m) }
    end
  end

  describe 'update' do
    let(:arguments) { ['domain', 'update', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'olddomain', 'alterednamespace'] }

    context 'when no issues with ' do
      before{ rest_client.add_domain("olddomain") }

      it "should update a domain" do
        expect { run }.should exit_with_code(0)
        rest_client.domains[0].id.should == 'alterednamespace'
      end
      it { run_output.should match(/Changing namespace 'olddomain' to 'alterednamespace'.*?RESULT:.*?Success/m) }
    end

    context 'when there is no domain' do
      it "should not create a domain" do
        expect { run }.should exit_with_code(127)
        rest_client.domains.empty?.should be_true
      end
      it { run_output.should match("does not exist") }
    end
  end

  describe 'alter alias' do
    let(:arguments) { ['domain', 'alter', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'olddomain', 'alterednamespace'] }

    context 'when no issues with ' do
      before{ rest_client.add_domain("olddomain") }

      it "should update a domain" do
        expect { run }.should exit_with_code(0)
        rest_client.domains[0].id.should == 'alterednamespace'
      end
      it { run_output.should match(/Changing namespace 'olddomain' to 'alterednamespace'.*?RESULT:.*?Success/m) }
    end
  end

  describe 'delete' do
    let(:arguments) { ['domain', 'delete', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'deleteme'] }

    context 'when no issues with ' do
      before{ rest_client.add_domain("deleteme") }

      it "should delete a domain" do
        expect { run }.should exit_with_code(0)
        rest_client.domains.empty?.should be_true
      end
    end

    context 'when there is a different domain' do
      before{ rest_client.add_domain("dontdelete") }

      it "should error out" do
        expect { run }.should exit_with_code(127)
        rest_client.domains[0].id.should == 'dontdelete'
      end
      it { run_output.should match("Domain deleteme does not exist") }
    end

    context 'when there are applications on the domain' do
      before(:each) do
        domain = rest_client.add_domain("deleteme")
        domain.add_application 'testapp1', 'mock-1.0'
      end
      it "should error out" do
        expect { run }.should exit_with_code(128)
        rest_client.domains[0].id.should == 'deleteme'
      end
      it { run_output.should match("Domain contains applications.*?Delete applications first.") }
    end
  end

  describe 'alias destroy' do
    let(:arguments) { ['domain', 'destroy', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'deleteme'] }

    context 'when no issues with ' do
      before{ rest_client.add_domain("deleteme") }

      it "should delete a domain" do
        expect { run }.should exit_with_code(0)
        rest_client.domains.empty?.should be_true
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
        @cmd.split.sort.should == "rhc-chk --server openshift.redhat.com --noprompt true --config test.conf --rhlogin test@test.foo --password password 2>&1".split.sort
      end
    end

    context '-d is passed' do
      let(:arguments) { ['domain', 'status', '-d', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }
      it "runs successfully" do
        expect { run }.should exit_with_code(0)
      end
    end
  end

  describe 'help' do
    let(:arguments) { ['domain', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.should exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc domain") }
    end
  end
end
