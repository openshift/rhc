include RHCHelper

And /^given an existing domain$/ do
  $namespace.nil?.should be_false, 'No existing namespace to alter'
end

When /^a new domain is needed and created$/ do
  Domain.create_if_needed
end

When /^a domain is altered$/ do
  Domain.alter
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
