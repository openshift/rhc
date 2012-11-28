require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/git_clone'

describe RHC::Commands::GitClone do
  before(:each) do
    FakeFS.activate!
    FakeFS::FileSystem.clear
    user_config
    @instance = RHC::Commands::GitClone.new
    RHC::Commands::GitClone.stub(:new) do
      @instance.stub(:git_config_get) { "" }
      @instance.stub(:git_config_set) { "" }
      Kernel.stub(:sleep) { }
      @instance.stub(:host_exists?) do |host|
        host.match("dnserror") ? false : true
      end
      @instance
    end
  end
  before(:each) do
    @rc = MockRestClient.new
    @domain = @rc.add_domain("mockdomain")
    @app = @domain.add_application("app1", "mock_unique_standalone_cart")
  end

  after(:each) do
    FakeFS.deactivate!
  end

  describe 'git-clone' do
    let(:arguments) { ['app', 'git-clone', 'app1'] }

    context "stubbing git_clone_repo" do
      context "reports success successfully" do
        before do
          @instance.stub(:git_clone_repo) do |git_url, repo_dir|
            Dir::mkdir(repo_dir)
            say "Cloned"
            true
          end
        end

        it { expect { run }.should exit_with_code(0) }
        it { run_output.should match("Cloned") }
      end

      context "reports failure" do
        before{ @instance.stub(:git_clone_repo).and_raise(RHC::GitException) }

        it { expect { run }.should exit_with_code(216) }
        it { run_output.should match("Git returned an error") }
      end
    end
  end
end
