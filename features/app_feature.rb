require 'spec_helper'
require 'direct_execution_helper'

describe "rhc app scenarios" do
  context "with an existing app" do
    before(:all) do
      standard_config
      @app = has_an_application
    end

    let(:app){ @app }

    it "should clone successfully" do
      app_name = "clone#{random}"
      r = rhc 'create-app', app_name, '--from-app', app.name
      r.stdout.should match /Domain:\s+#{app.domain}/
      r.stdout.should match /Cartridges:\s+#{app.cartridges.collect{|c| c.name}.join(', ')}/
      r.stdout.should match /From app:\s+#{app.name}/
      r.stdout.should match /Gear Size:\s+Copied from '#{app.name}'/
      r.stdout.should match /Scaling:\s+#{app.scalable? ? 'yes' : 'no'}/
      r.stdout.should match /Setting deployment configuration/
      r.stdout.should match /Pulling down a snapshot of application '#{app.name}'/
    end
  end
end
