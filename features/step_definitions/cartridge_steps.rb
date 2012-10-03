require 'fileutils'
require 'rhc/config'

include RHCHelper

When /^the (.+) cartridge is added$/ do |name|
  @app.add_cartridge name
end

When /^the (.+) cartridge is removed$/ do |name|
  @app.remove_cartridge name
end

When /^the (.+) cartridge is (stopped|(?:re)?started)$/ do |name,command|
  cmd = case command.to_sym
        when :stopped
          'stop'
        when :started
          'start'
        when :restarted
          'restart'
        end
  @app.cartridge(name).send(cmd)
end

Then /^the (.+) cartridge should be (.*)$/ do |name,status|
  expected = case status.to_sym
             when :running
               "(.+) is running|Uptime:"
             when :stopped
               "(.+) stopped"
             when :removed
               "Invalid cartridge specified: '#{name}'"
             end
  @app.cartridge(name).status.should match(expected)
end

Then /^adding the (.+) cartridge should fail$/ do |name|
  @app.add_cartridge(name).should == 154
end
