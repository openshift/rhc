include RHCHelper
When /^a new domain is needed and created$/ do
  Domain.create_if_needed
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
