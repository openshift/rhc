require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/domain'

describe RHC::Commands::Domain do
  let(:rest_client){ MockRestClient.new }
  before{ user_config }

  describe 'default action' do
    before{ rest_client }
    context 'when run with no domains' do
      let(:arguments) { ['domain'] }

      it { expect { run }.to exit_with_code(1) }
      it { run_output.should match(/To create your first domain.*rhc create-domain/m) }
    end
    context 'when help is shown' do
      let(:arguments) { ['domain', '--noprompt', '--help'] }

      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match(/configure.*delete.*leave.*list.*rename/m) }
    end
  end

  describe 'show' do
    before{ rest_client }
    let(:arguments) { ['domain', 'show'] }

    context 'when run with no domains' do
      it { expect { run }.to exit_with_code(1) }
      it { run_output.should match(/In order to deploy applications, you must create a domain/m) }
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
      before do
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
      before do
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
      before do
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
    before{ rest_client }
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

      context 'when has no creation date, members, or allowed_gear_sizes' do
        before{ rest_client.domains.first.attributes.merge(:creation_date => nil, :allowed_gear_sizes => nil, :members => nil, :id => '123') }
        it { expect { run }.to exit_with_code(0) }
        it "should match output" do
          output = run_output
          output.should match("onedomain")
          output.should_not match ("Allowed Gear Sizes:")
          output.should_not match ("Created:")
          output.should_not match ("Members:")
          output.should_not match ("ID:.*")
        end
      end
      context 'when an ID is present and differs from name' do
        let(:arguments) { ['domain', 'list', '--ids'] }
        before{ rest_client.domains.first.attributes['id'] = '123' }
        it { expect { run }.to exit_with_code(0) }
        it "should match output" do
          output = run_output
          output.should match("onedomain")
          output.should match ("ID:.*123")
        end
      end
      context 'when an ID is present and identical to name' do
        let(:arguments) { ['domain', 'list', '--ids'] }
        before{ rest_client.domains.first.attributes['id'] = 'onedomain' }
        it { expect { run }.to exit_with_code(0) }
        it "should not match output" do
          run_output.should_not match ("ID:.*123")
        end
      end
      context 'when an ID is present and name is not' do
        let(:arguments) { ['domain', 'list', '--ids'] }
        before{ rest_client.domains.first.attributes['id'] = 'onedomain' }
        before{ rest_client.domains.first.instance_variable_set(:@name, nil) }
        it { expect { run }.to exit_with_code(0) }
        it "should match output" do
          run_output.should match ("onedomain")
          run_output.should_not match ("ID:.*")
        end
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
      before do
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
    before{ rest_client }
    let(:arguments) { ['domain', 'create', 'testnamespace'] }

    context 'when no issues with ' do

      it "should create a domain" do
        expect { run }.to exit_with_code(0)
        rest_client.domains[0].name.should == 'testnamespace'
      end
      it { run_output.should match(/Creating.*'testnamespace'.*done/m) }
    end
  end

  describe 'rename' do
    before{ rest_client }
    let(:arguments) { ['domain', 'rename', 'olddomain', 'alterednamespace'] }

    context 'when no issues with ' do
      before{ rest_client.add_domain("olddomain") }

      it "should update a domain" do
        expect { run }.to exit_with_code(0)
        rest_client.domains[0].name.should == 'alterednamespace'
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

  describe 'update' do
    before{ rest_client }
    let(:arguments) { ['domain', 'update', 'olddomain', 'alterednamespace'] }

    before{ rest_client.add_domain("olddomain") }
    it "should update a domain" do
      expect { run }.to exit_with_code(0)
      rest_client.domains[0].name.should == 'alterednamespace'
    end
    it { run_output.should match(/This command is deprecated.*Renaming domain 'olddomain' to 'alterednamespace'.*done.*?Applications in this domain will use the new name in their URL./m) }
  end

  describe 'alter alias has been removed' do
    let(:arguments) { ['domain', 'alter', 'olddomain', 'alterednamespace'] }
    it{ expect { run }.to exit_with_code(1) }
  end

  describe 'configure' do
    context "no settings" do
      before{ rest_client.add_domain("domain1") }
      let(:arguments) { ['domain', 'configure', '-n', 'domain1'] }
      it("should succeed"){ expect { run }.to exit_with_code(0) }
      it("should display the domain config"){ run_output.should match(/Domain domain1 configuration/m) }
      it("should not display the domain config without gear sizes"){ run_output.should_not match(/Allowed Gear Sizes/) }

      context "server supports allowed gear sizes" do
        before{ rest_client.domains.first.should_receive(:allowed_gear_sizes).and_return([]) }
        it("should display the domain config"){ run_output.should match(/Domain domain1 configuration.*Allowed Gear Sizes:\s+<none>/m) }
      end
      context "server supports allowed gear sizes" do
        before{ rest_client.domains.first.should_receive(:allowed_gear_sizes).and_return(['small', 'medium']) }
        it("should display the domain config"){ run_output.should match(/Domain domain1 configuration.*Allowed Gear Sizes:\s+small, medium/m) }
      end
    end

    context "when server does not support allowed-gear-sizes" do
      before do
        rest_client.add_domain("domain1")
        rest_client.api.should_receive(:has_param?).with(:add_domain, 'allowed_gear_sizes').and_return(false)
      end
      let(:arguments) { ['domain', 'configure', '--allowed-gear-sizes', 'small'] }
      it("display a message"){ run_output.should match 'The server does not support --allowed-gear-sizes' }
    end

    context "against a server that supports gear sizes" do
      let(:username){ 'test_user' }
      let(:password){ 'password' }
      let(:server){ 'test.domain.com' }
      let(:supports_allowed_gear_sizes?){ true }
      before{ subject.class.any_instance.stub(:namespace_context).and_return('domain1') }
      before do
        stub_api
        challenge{ stub_one_domain('domain1', nil, mock_user_auth) }
      end

      context "with --allowed-gear-sizes singular" do
        before do
          stub_api_request(:put, "domains/domain1/update", nil).
            with(:body => {:allowed_gear_sizes => ['valid']}).
            to_return({:body => {:type => 'domain', :data => {:name => 'domain1', :allowed_gear_sizes => ['valid']}, :messages => [{:severity => 'info', :text => 'Updated allowed gear sizes'},]}.to_json, :status => 200})
        end
        let(:arguments) { ['domain', 'configure', '--trace', '--allowed-gear-sizes', 'valid'] }
      it("should succeed"){ expect { run }.to exit_with_code(0) }
      it("should display the domain config"){ run_output.should match(/Domain domain1 configuration.*Allowed Gear Sizes:\s+valid/m) }
      end

      context "with --allowed-gear-sizes multiple" do
        before do
          stub_api_request(:put, "domains/domain1/update", nil).
            with(:body => {:allowed_gear_sizes => ['one', 'two']}).
            to_return({:body => {:type => 'domain', :data => {:name => 'domain1', :allowed_gear_sizes => ['one', 'two']}, :messages => [{:severity => 'info', :text => 'Updated allowed gear sizes'},]}.to_json, :status => 200})
        end
        let(:arguments) { ['domain', 'configure', '--trace', '--allowed-gear-sizes', 'one,two'] }
        it("should succeed"){ expect { run }.to exit_with_code(0) }
        it("should display the domain config"){ run_output.should match(/Domain domain1 configuration.*Allowed Gear Sizes:\s+one, two/m) }
      end

      context "with --allowed-gear-sizes" do
        let(:arguments) { ['domain', 'configure', 'domain1', '--trace', '--allowed-gear-sizes'] }
        it("raise an invalid option"){ expect{ run }.to raise_error(OptionParser::InvalidOption, /Provide a comma delimited list of valid gear/) }
      end

      context "with --allowed-gear-sizes=false" do
        before do
          stub_api_request(:put, "domains/domain1/update", nil).
            with(:body => {:allowed_gear_sizes => ['false']}).
            to_return({:body => {:type => 'domain', :messages => [{:field => 'allowed_gear_sizes', :exit_code => 10, :severity => 'error', :text => 'The specified gear size is invalid: false'},]}.to_json, :status => 422})
        end
        let(:arguments) { ['domain', 'configure', '--allowed-gear-sizes=false'] }
        it("should succeed"){ expect { run }.to exit_with_code(1) }
        it("should display the domain config"){ run_output.should match(/Updating domain configuration.*The specified gear size is invalid/m) }
      end

      context "with --no-allowed-gear-sizes" do
        before do
          stub_api_request(:put, "domains/domain1/update", nil).
            with(:body => {:allowed_gear_sizes => []}).
            to_return({:body => {:type => 'domain', :data => {:name => 'domain1', :allowed_gear_sizes => []}, :messages => [{:severity => 'info', :text => 'Updated allowed gear sizes'},]}.to_json, :status => 200})
        end
        let(:arguments) { ['domain', 'configure', '--no-allowed-gear-sizes'] }
        it("should succeed"){ expect { run }.to exit_with_code(0) }
        it("should display the domain config"){ run_output.should match(/Domain domain1 configuration.*Allowed Gear Sizes:\s+<none>/m) }
      end

      context "with --allowed-gear-sizes and --no-allowed-gear-sizes" do
        let(:arguments) { ['domain', 'configure', 'domain1', '--trace', '--no-allowed-gear-sizes', '--allowed-gear-sizes', 'small'] }
        it("raise an invalid option"){ expect{ run }.to raise_error(OptionParser::InvalidOption, /--allowed-gear-sizes.*--no-allowed-gear-sizes/) }
      end
    end
  end

  describe 'leave' do
    before{ rest_client.add_domain("deleteme") }
    let(:arguments) { ['domain', 'leave', '-n', 'deleteme'] }

    it "should leave the domain" do
      rest_client.domains.first.should_receive(:leave)
      expect { run }.to exit_with_code(0)
    end
  end

  describe 'delete' do
    before{ rest_client }
    let(:arguments) { ['domain', 'delete', 'deleteme'] }

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
        rest_client.domains[0].name.should == 'dontdelete'
      end
      it { run_output.should match("Domain deleteme not found") }
    end

    context 'when there are applications on the domain' do
      before do
        domain = rest_client.add_domain("deleteme")
        domain.add_application 'testapp1', 'mock-1.0'
      end
      it "should error out" do
        expect { run }.to exit_with_code(1)
        rest_client.domains[0].name.should == 'deleteme'
      end
      it { run_output.should match("Applications must be empty") }
    end

    context 'when delete is forced' do
      let(:arguments) { ['domain', 'delete', 'deleteme', '--force'] }
      before do
        domain = rest_client.add_domain("deleteme")
        domain.add_application 'testapp1', 'mock-1.0'
      end
      it "should delete successfully" do
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
