require 'spec_helper'
require 'rest_spec_helper'
require 'rhc'
require 'rhc/commands/account'

describe RHC::Commands::Account do

  describe 'run' do
    let(:arguments) { ['account'] }
    let(:username) { 'foo' }
    let(:password) { 'pass' }
    let(:server) { mock_uri }
    before{ user_config }
    before do
      stub_api(true)
      stub_user
    end

    it('should display the correct user') { run_output.should =~ /Login:\s*#{username}/ }
    it('should not show') { run_output.should_not =~ /Plan:/ }
    it('should show the gear capabilities') { run_output.should =~ /Allowed Gear Sizes:\s*small/ }
    it('should show the consumed gears') { run_output.should =~ /Gears Used:\s*0/ }
    it('should show the maximum gears') { run_output.should =~ /Gears Allowed:\s*3/ }
    it { expect { run }.should exit_with_code(0) }

    context 'with a freeshift plan' do
      let(:user_plan_id){ 'freeshift' }
      it('should show') { run_output.should =~ /Plan:\s*FreeShift/ }
    end

    context 'with a megashift plan' do
      let(:user_plan_id){ 'megashift' }
      it('should show') { run_output.should =~ /Plan:\s*MegaShift/ }
    end

    context 'with a arbitrary plan' do
      let(:user_plan_id){ 'other' }
      it('should show') { run_output.should =~ /Plan:\s*Other/ }
    end
  end
end
