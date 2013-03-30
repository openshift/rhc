Given 'we have the client tools setup' do
  step 'the libra client tools'
  step 'the client tools should be setup if needed'
end

Given 'we have an existing domain' do
  step 'we have the client tools setup'
  step 'a new domain is needed and created'
  begin
    step 'the key "key1" is shown'
    step 'the output includes the key information for "key1"'
  rescue RSpec::Expectations::ExpectationNotMetError
    step 'a new SSH key "key1.pub" is added as "key1"'
  end
end

Given /^we have a (.*) (.*) cartridge$/ do |status,type|
  cmd = case status
        when "running"
          "started"
        else
          status
        end

  # Ensure the cartridge is in the right state for the tests
  #  only try once
  retried = false
  begin
    step "the #{type} cartridge should be #{status}"
  rescue RSpec::Expectations::ExpectationNotMetError
    step "the #{type} cartridge is #{cmd}"
    (retried = true && retry) unless retried
  end
end

Given /^we have a (stopped|running) application$/ do |state|
  (before,after) = case state
                   when "stopped"
                     ["not be accessible","stopped"]
                   when "running"
                     ["be accessible","started"]
                   end

  begin
    step "the application should #{before}"
  rescue RSpec::Expectations::ExpectationNotMetError
    step "the application is #{after}"
  end
end
