require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/apps'

describe RHC::Commands::Apps do
  before{ user_config }
  let!(:rest_client){ MockRestClient.new }

  describe 'run' do
    context 'when no domains' do
      let(:arguments) { ['apps'] }

      it { expect { run }.to exit_with_code(1) }
      it { run_output.should match(/In order to deploy applications.*rhc create-domain/) }
    end

    context 'with a domain' do
      let(:arguments){ ['apps'] }
      let!(:domain){ rest_client.add_domain("first") }

      it { expect { run }.to exit_with_code(1) }
      it { run_output.should match(/No applications.*rhc create-app/) }

      context 'with apps' do
        let(:arguments) { ['apps'] }
        before{ domain.add_application('scaled', 'php', true) }

        it { expect { run }.to exit_with_code(0) }
        it "should match output" do
          output = run_output
          output.should match("You have access to 1 application\\.")
          output.should match(/scaled.*\-\-.*php.*Scaling:.*x2 \(minimum/m)
        end
      end

      context 'with one owned app' do
        let(:arguments) { ['apps', '--mine'] }
        before{ a = domain.add_application('scaled', 'php', true); rest_client.stub(:owned_applications).and_return([a]) }
        it { expect { run }.to exit_with_code(0) }
        it "should match output" do
          output = run_output
          output.should match("You have 1 application\\.")
          output.should match(/scaled.*\-\-.*php.*Scaling:.*x2 \(minimum/m)
        end
      end

    end

    context 'when help is shown' do
      let(:arguments) { ['apps', '--help'] }
      it { expect { run }.to exit_with_code(0) }
      it { run_output.should match(/rhc apps.*Display the list of applications/m) }
    end

    context 'when run verbose with custom external cartridges' do
      let(:arguments) { ['apps', '-v'] }
      before do
        @domain = rest_client.add_domain("mockdomain")
        app = @domain.add_application("app1", "mock_type")
        cart1 = app.add_cartridge('mock_cart-1')
        cart1.url = 'https://foo.bar.com'
        cart1.tags = ['external']
        cart1.version = '2'
        cart1.license = 'GPL'
        cart1.website = 'http://bar.com'
        cart1.current_scale = 0
      end
      it { run_output.should match("app1 @ https://app1-mockdomain.fake.foo/") }
      it { run_output.should match(/Gears:\s+1 small/) }
      it { run_output.should match(/Gears:\s+none \(external service\)/) }
      it { run_output.should match(/Description:\s+Description of mock_cart-1/) }
      it { run_output.should match(%r(Website:\s+ http://bar.com)) }
      it { run_output.should match(/Version:\s+2/) }
      it { run_output.should match(/License:\s+GPL/) }
      it { run_output.should match(%r(From:\s+ https://foo.bar.com)) }
    end

  end
end
