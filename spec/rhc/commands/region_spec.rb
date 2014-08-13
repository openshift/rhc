require 'spec_helper'
require 'rest_spec_helper'
require 'rhc/commands/region'
require 'rhc/config'

describe RHC::Commands::Region do
  before{ user_config }

  describe 'region list' do
    let(:arguments){ ['region', 'list'] }
    let(:username){ nil }
    let(:password){ nil }
    let(:server){ mock_uri }
    let(:user_auth){ false }

    context 'with server regions' do
      before do 
        stub_api 
        stub_simple_regions
      end

      it{ run_output.should match /Server test\.domain\.com$/ }
      it{ run_output.should match /Region 'north' \(uuid: region0001\)$/ }
      it{ run_output.should match /Description:\s+Servers in the north of US$/ }
      it{ run_output.should match /Available Zones:\s+east, west$/ }
      it{ run_output.should match /Region 'south' \(uuid: region0002\) \(default\)/ }
      it{ run_output.should match /Available Zones: east$/ }
      it{ expect{ run }.to exit_with_code(0) }
    end

    context 'when allowing region selection' do
      before do 
        stub_api 
        stub_simple_regions(false, true)
      end
      it{ run_output.should match /To create an app in a specific region use/ }
      it{ expect{ run }.to exit_with_code(0) }
    end

    context 'when not allowing region selection' do
      before do 
        stub_api 
        stub_simple_regions(false, false)
      end
      it{ run_output.should match /Regions can't be explicitly provided by users/ }
      it{ expect{ run }.to exit_with_code(0) }
    end

    context 'without server regions' do
      before do 
        stub_api 
        stub_simple_regions(true)
      end

      it{ run_output.should_not match /Available Zones$/ }
      it{ run_output.should match /Server doesn't have any regions or zones configured/ }
      it{ expect{ run }.to exit_with_code(169) }
    end

    context 'regions not supported on server' do
      let!(:rest_client){ MockRestClient.new }
      it{ run_output.should_not match /Available Zones$/ }
      it{ run_output.should match /Server does not support regions and zones/ }
      it{ expect{ run }.to exit_with_code(168) }
    end
  end

end
