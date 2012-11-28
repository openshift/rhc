require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/apps'

describe RHC::Commands::Apps do
  before{ user_config }
  let!(:rest_client){ MockRestClient.new }

  describe 'run' do
    context 'when no domains' do
      let(:arguments) { ['apps'] }

      it { expect { run }.should exit_with_code(1) }
      it { run_output.should match(/In order to deploy applications.*rhc domain create/) }
    end

    context 'with a domain' do
      let(:arguments){ ['apps'] }
      let!(:domain){ rest_client.add_domain("first") }

      it { expect { run }.should exit_with_code(1) }
      it { run_output.should match(/No applications.*rhc app create/) }

      context 'with apps' do
        let(:arguments) { ['apps'] }
        before{ domain.add_application('scaled', 'php', true) }

        it { expect { run }.should exit_with_code(0) }
        it { run_output.should match(/scaled.*==.*php.*Scaling:.*x2 \(minimum/m) }
      end
    end

    context 'when help is shown' do
      let(:arguments) { ['apps', '--help'] }
      it { expect { run }.should exit_with_code(0) }
      it { run_output.should match(/rhc apps.*Display the list of applications/m) }
    end
  end
end
