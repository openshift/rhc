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

When /^we are updating the (.+) cartridge$/ do |cart|
  @cartridge_name = cart
end

When /^the (\w+) scaling value is set to (.*)$/ do |minmax,value|
  @exitcode = @app.cartridge(@cartridge_name).send(:scale,"--#{minmax} #{value}")
end

When /^we list cartridges$/ do
  @exitcode, @cartridge_output = Cartridge.list
end

Then /^the (\w+) scaling value should be (.*)$/ do |minmax,value|
  expected = {
    :min => "Minimum",
    :max => "Maximum"
  }[minmax.to_sym]

  value = (value == "-1" ? "available gears" : value)

  match_string = [expected,value].join(" = ")
  regex = Regexp.new(/\s+#{match_string}/)

  @app.cartridge(@cartridge_name).send(:show).should match(regex)
end

Then /^it should fail with code (\d+)$/ do |code|
  @exitcode.should == code.to_i
end

Then /^the list should contain the cartridge ([^\s]+) with display name "([^"]+)"$/ do |name, display_name|
  line = @cartridge_output.each_line.find{ |s| s.include?(name) }
  line.should_not be_nil
  line.should match(display_name)
end
