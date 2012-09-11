Given 'we have the client tools setup' do
  step 'the libra client tools'
  step 'the client tools should be setup if needed'
end

Given 'we have an existing domain' do
  step 'we have the client tools setup'
  step 'a new domain is needed and created'
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
  rescue Spec::Expectations::ExpectationNotMetError
    step "the #{type} cartridge is #{cmd}"
    (retried = true && retry) unless retried
  end
end

Given /^we have a (stopped|running) application$/ do |state|
  begin
    step "the application should not be accessible"
    step "the application is started" if state == "running"
  rescue Spec::Expectations::ExpectationNotMetError
    step "the application is stopped" if state == "stopped"
  end
end
