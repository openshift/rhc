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
        else
          raise "Unrecognized command type #{status}"
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
               "There are no cartridges that match '#{name}'"
             else
               raise "Unrecognized status type #{status}"
             end
  @app.cartridge(name).status.should match(expected)
end

Then /^adding the (.+) cartridge should fail$/ do |name|
  @app.add_cartridge(name).should == 154
end

When /^we are updating the (.+) cartridge$/ do |cart|
  @cartridge_name = cart
end

When /^the (\w+) scaling value is set to (.*)$/ do |minmax,value|
  @exitcode = @app.cartridge(@cartridge_name).send(:scale,"--#{minmax} #{value}")
end

When /^we list cartridges$/ do
  @exitcode, @cartridge_output = Cartridge.list
end

When /^we (.+) storage for the (.+) cartridge$/ do |storage_action,cartridge|
  @output = @app.cartridge(@cartridge_name).send(:storage, cartridge, "--#{storage_action}")
end

Then /^the (\w+) scaling value should be (.*)$/ do |minmax,value|
  expected = {
    :min => "minimum",
    :max => "maximum"
  }[minmax.to_sym]

  value = (value == "-1" ? "available" : value)

  match_string = [expected,value].join(": ")
  regex = Regexp.new(/\b#{match_string}/)

  @app.cartridge(@cartridge_name).send(:show).should match(regex)
end

Then /^the additional cartridge storage amount should be (\w+)$/ do |value|
  @output.should == value
end

Then /^it should fail with code (\d+)$/ do |code|
  @exitcode.should == code.to_i
end

Then /^the list should contain the cartridge ([^\s]+) with display name "([^"]+)"$/ do |name, display_name|
  line = @cartridge_output.each_line.find{ |s| s.include?(name) }
  line.should_not be_nil
  line.should match(display_name)
end
