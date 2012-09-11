include RHCHelper

Before do
  Sshkey.remove "key1"
  Sshkey.remove "key2"
end

When /^'rhc sshkey (\S+)( .*?)?'(?: command)? is run$/ do |subcommand, rest|
  if subcommand =~ /^(list|show|add|remove|delete|update)$/
    Sshkey.send subcommand.to_sym, rest
    @sshkey_output = Sshkey.sshkey_output
    @exitcode      = Sshkey.exitcode
  end
end

Given /^the SSH key "(.*?)" does not exist$/ do |key|
  Sshkey.remove "key"
end

Given /^the SSH key "(.*?)" already exists$/ do |key|
  keyfile = File.join(File.dirname(__FILE__), '..', 'support', key + '.pub')
  step "'rhc sshkey add #{key} #{keyfile}' is run"
end

Given /^an SSH key "(.*?)" with the same content as "(.*?)" exists$/ do |existing_key, new_key|
  keyfile = File.join(File.dirname(__FILE__), '..', 'support', new_key + '.pub')
  step "a new SSH key \"#{keyfile}\" is added as \"#{existing_key}\""
end

When /^a new SSH key "(.*?)" is added as "(.*)"$/ do |keyfile, name|
  step "'rhc sshkey add #{name} #{keyfile}' is run"
end

Then /^the output includes the key information for "(.*?)"$/ do |key|
  @sshkey_output.should match /Name: #{key}/
end

Then /^the output includes deprecation warning$/ do
  @sshkey_output.should match /deprecated/
end

Then /^the key "(.*?)" should exist$/ do |key|
  Sshkey.show "#{key}"
  Sshkey.sshkey_output.should =~ /Name: #{key}/
end

Then /^the SSH key "(.*?)" is deleted$/ do |key|
  Sshkey.show "#{key}"
  Sshkey.sshkey_output.should_not =~ /Name: #{key}/
end

Then /^the output includes the key information$/ do
  @sshkey_output.should match /Name:.*Type:.*Fingerprint:/m
end

Then /^the command exits with status code (\d+)$/ do |arg1|
  code = arg1.to_i
  @exitcode.should == code
end

