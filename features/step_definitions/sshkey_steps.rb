include RHCHelper

When /^'rhc sshkey (\S+)( .*?)?'(?: command)? is run$/ do |subcommand, rest|
  if subcommand =~ /^(list|show|add|remove|delete|update)$/
    Sshkey.send subcommand.to_sym, rest
    @sshkey_output = Sshkey.sshkey_output
    @exitcode      = Sshkey.exitcode
  end
end

Given "the existing keys are listed" do
  step "'rhc sshkey list' is run"
end

Given /^the key "(.*?)" is (.*)$/ do |key,cmd|
  cmd = case cmd
        when "shown"
          "show"
        when "removed"
          "remove"
        end
  step "'rhc sshkey #{cmd} \"#{key}\"' is run"
end

When /^a new SSH key "(.*?)" is added as "(.*)"$/ do |keyfile, name|
  keyfile = Sshkey.keyfile_path(keyfile)
  step "'rhc sshkey add #{name} #{keyfile}' is run"
end

Then /^the command exits with status code (\d+)$/ do |arg1|
  code = arg1.to_i
  @exitcode.should == code
end

Then /^the output (does not include|includes) (.*)$/ do |includes,str|
  regex = case str
          when /^the key information for "(.*?)"$/
            /Name: #{$1}/
          when "deprecation warning"
            /deprecated/
          when "the key information"
            /Name:.*Type:.*Fingerprint:/m
          end
  includes = case includes
             when "does not"
               false
             when "includes"
               true
             end

  if includes
    @sshkey_output.should match regex
  else
    @sshkey_output.should_not match regex
  end
end
