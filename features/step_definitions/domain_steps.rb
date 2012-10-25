include RHCHelper

And /^an existing domain$/ do
  $namespace.nil?.should be_false, 'No existing namespace to alter'
end

And /^given domains is empty$/ do
  $namespace.nil?.should be_true
end

When /^a new domain is needed and created$/ do
  Domain.create_if_needed
end

When /^domain is updated$/ do
  Domain.update
end

When /^domain is deleted$/ do
  Domain.delete
end

When /^rhc domain (.*)is run$/ do |action|
  action.rstrip!
  cmd = "rhc_domain"
  cmd += "_#{action}" if action.length > 0
  Domain.send(:"#{cmd}")
end

Then /^the default domain action output should equal the show action output$/ do
  Domain.domain_output.should match($namespace)

  domain_output = Domain.domain_output.lines.sort
  domain_show_output = Domain.domain_show_output.lines.sort

  # check line by line while ignoring debug output which is timestamped
  domain_output.zip(domain_show_output) do |a, b|
    a.should == b unless a.match("DEBUG") 
  end
end

Then /^the domain should be reserved?$/ do
  # Sleep to allow DNS to propogate
  sleep 5

  # Check for up to a minute
  resolved = false
  120.times do
    resolved = Domain.reserved?
    break if resolved
    sleep 1
  end

  resolved.should be_true, 'Not able to lookup DNS TXT record in time.'
end

Then /^the domain command should fail with an exitcode of (\d*)$/ do |exitcode|
  exitcode = exitcode.to_i
  Domain.exitcode.should == exitcode
end

Then /^domains should be empty$/ do
  $namespace.should be_nil
end

When /^rhc domain create is called$/ do
  Domain.create
end
