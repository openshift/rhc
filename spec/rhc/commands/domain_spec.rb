require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/domain'

describe RHC::Commands::Domain do
  let!(:rest_client){ MockRestClient.new }
  before{ user_config }

  describe 'default action' do
    context 'when run with no domains' do
      let(:arguments) { ['domain', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

      it { expect { run }.to exit_with_code(1) }
      it { run_output.should match(/In order to deploy applications.*rhc create-domain/) }
    end
    context 'when help is shown' do
      let(:arguments) { ['domain', '--noprompt', '--help'] }

      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match(/The default action for this resource is 'list'/) }
    end
  end

  describe 'show' do
    let(:arguments) { ['domain', 'show', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password'] }

    context 'when run with no domains' do
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should match(/In order to deploy applications.*rhc create-domain/) }
    end

    context 'when run with one domain no apps' do
      before{ rest_client.add_domain("onedomain") }

      it { expect { run }.to exit_with_code(0) }
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
      it { expect { run }.to exit_with_code(0) }
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
      it { expect { run }.to exit_with_code(0) }
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
      it { expect { run }.to exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("app_no_carts")
        output.should match(/127.0.0.1\s*$/m)
      end
    end
  end


  describe 'list' do
    let(:arguments) { ['domain', 'list'] }

    context 'when run with no domains' do
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should match(/In order to deploy applications.*rhc create-domain/) }
    end

    context 'when run with one domain no apps' do
      before{ rest_client.add_domain("onedomain") }

      it { expect { run }.to exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("You have access to 1 domain\\.")
        output.should match("onedomain")
      end
    end

    context 'when run with one owned domain' do
      let(:arguments) { ['domains', '--mine'] }
      before{ d = rest_client.add_domain('mine', true); rest_client.stub(:owned_domains).and_return([d]) }

      it { expect { run }.to exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("You have access to 1 domain\\.")
        output.should match("mine")
        output.should match("Created")
        output.should match("Allowed Gear Sizes: small")
      end
    end

    context 'when run with multiple domains and extra domain info' do
      before(:each) do
        rest_client.add_domain("firstdomain")
        rest_client.add_domain("seconddomain", true)
      end
      it { expect { run }.to exit_with_code(0) }
      it "should match output" do
        output = run_output
        output.should match("You have access to 2 domains")
        output.should match("seconddomain \\(owned by a_user_name\\)")
        output.should match("Created")
        output.should match("Allowed Gear Sizes: small")
      end
    end
  end

  describe 'create' do
    let(:arguments) { ['domain', 'create', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'testnamespace'] }

    context 'when no issues with ' do

      it "should create a domain" do
        expect { run }.to exit_with_code(0)
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
        expect { run }.to exit_with_code(0)
        rest_client.domains[0].id.should == 'alterednamespace'
      end
      it { run_output.should match(/Renaming domain 'olddomain' to 'alterednamespace'.*done.*?Applications in this domain will use the new name in their URL./m) }
    end

    context 'when there is no domain' do
      it "should not create a domain" do
        expect { run }.to exit_with_code(127)
        rest_client.domains.empty?.should be_true
      end
      it { run_output.should match("not found") }
    end
  end

  describe 'alter alias' do
    let(:arguments) { ['domain', 'alter', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'olddomain', 'alterednamespace'] }

    context 'when no issues with ' do
      before{ rest_client.add_domain("olddomain") }

      it "should update a domain" do
        expect { run }.to exit_with_code(0)
        rest_client.domains[0].id.should == 'alterednamespace'
      end
      it { run_output.should match(/Renaming domain 'olddomain' to 'alterednamespace'.*done.*?Applications in this domain will use the new name in their URL./m) }
    end
  end

  describe 'delete' do
    let(:arguments) { ['domain', 'delete', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'deleteme'] }

    context 'when no issues with ' do
      before{ rest_client.add_domain("deleteme") }

      it "should delete a domain" do
        expect { run }.to exit_with_code(0)
        rest_client.domains.empty?.should be_true
      end
    end

    context 'when there is a different domain' do
      before{ rest_client.add_domain("dontdelete") }

      it "should error out" do
        expect { run }.to exit_with_code(127)
        rest_client.domains[0].id.should == 'dontdelete'
      end
      it { run_output.should match("Domain deleteme not found") }
    end

    context 'when there are applications on the domain' do
      before(:each) do
        domain = rest_client.add_domain("deleteme")
        domain.add_application 'testapp1', 'mock-1.0'
      end
      it "should error out" do
        expect { run }.to exit_with_code(128)
        rest_client.domains[0].id.should == 'deleteme'
      end
      it { run_output.should match("Your domain contains applications.*?Delete applications first.") }
    end
  end

  describe 'alias destroy' do
    let(:arguments) { ['domain', 'destroy', '--noprompt', '--config', 'test.conf', '-l', 'test@test.foo', '-p',  'password', 'deleteme'] }

    context 'when no issues with ' do
      before{ rest_client.add_domain("deleteme") }

      it "should delete a domain" do
        expect { run }.to exit_with_code(0)
        rest_client.domains.empty?.should be_true
      end
    end
  end

  describe 'help' do
    let(:arguments) { ['domain', '--help'] }

    context 'help is run' do
      it "should display help" do
        expect { run }.to exit_with_code(0)
      end
      it('should output usage') { run_output.should match("Usage: rhc domain") }
    end
  end
end
