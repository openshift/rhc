require 'spec_helper'
require 'direct_execution_helper'

describe "rhc domain scenarios" do
  context "with an existing domain" do
    before(:all) do
      standard_config
      @domain = has_a_domain
    end
    let(:domain){ @domain }

    it "should display the domain configuration" do
      r = rhc 'configure-domain', domain.id
      r.status.should == 0
      r.stdout.should match "Allowed Gear Sizes:\s+#{domain.allowed_gear_sizes.join(", ")}"
    end

    it "should change the domain configuration" do
      r = rhc 'configure-domain', domain.id, '--no-allowed-gear-sizes'
      r.status.should == 0
      r.stdout.should match "Allowed Gear Sizes:\s+<none>$"
      client.reset.find_domain(domain.id).allowed_gear_sizes.should == []

      all_sizes = client.user.capabilities.gear_sizes
      r = rhc 'configure-domain', domain.id, '--allowed-gear-sizes', all_sizes.join(',')
      r.status.should == 0
      r.stdout.should match "Allowed Gear Sizes:\s+#{all_sizes.join(', ')}$"
      client.reset.find_domain(domain.id).allowed_gear_sizes.should == all_sizes
    end

    it "should reject invalid gear size configuration changes" do
      all_sizes = client.user.capabilities.gear_sizes

      r = rhc 'configure-domain', domain.id, '--allowed-gear-sizes', '_not_a_size_'
      r.status.should_not == 1
      r.stdout.should match "Updating domain configuration.*The following gear sizes are invalid: _not_a_size_"
      client.reset.find_domain(domain.id).allowed_gear_sizes.should == all_sizes

      r = rhc 'configure-domain', domain.id, '--allowed-gear-sizes'
      r.status.should_not == 1
      r.stdout.should match "invalid option: Provide a comma delimited .* --allowed-gear-sizes"
      client.reset.find_domain(domain.id).allowed_gear_sizes.should == all_sizes
    end
  end
end