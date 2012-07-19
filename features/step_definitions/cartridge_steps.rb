require 'fileutils'
require 'rhc/config'

include RHCHelper

When /^the (.+) cartridge is added$/ do |name|
  @app.add_cartridge name
end

When /^the (.+) cartridge is stopped$/ do |name|
  @app.cartridge(name).stop
end

When /^the (.+) cartridge is restarted$/ do |name|
  @app.cartridge(name).restart
end

When /^the (.+) cartridge is started$/ do |name|
  @app.cartridge(name).start
end

When /^the (.+) cartridge is removed$/ do |name|
  @app.remove_cartridge name
end

Then /^the (.+) cartridge should be running$/ do |name|
  @app.cartridge(name).status.should match("RESULT:\n(.+) is running|RESULT:\n(\n|.)+Uptime:")
end

Then /^the (.+) cartridge should be stopped$/ do |name|
  @app.cartridge(name).status.should match("RESULT:\n(.+) stopped")
end

Then /^the (.+) cartridge should be removed$/ do |name|
  # look for response code 400
  @app.cartridge(name).status.should match("Response code was 400")
end


Then /^adding the (.+) cartridge should fail$/ do |name|
  @app.add_cartridge(name).should == 1
end
