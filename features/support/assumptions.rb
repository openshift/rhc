Given 'we have the client tools setup' do
  When 'the libra client tools'
  When 'the client tools should be setup if needed'
end

Given 'we have an existing domain' do
  When 'we have the client tools setup'
  When 'a new domain is needed and created'
  begin
    When 'the key "key1" is shown'
    Then 'the output includes the key information for "key1"'
  rescue Spec::Expectations::ExpectationNotMetError
    Given 'a new SSH key "key1.pub" is added as "key1"'
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
    When "the #{type} cartridge should be #{status}"
  rescue Spec::Expectations::ExpectationNotMetError
    When "the #{type} cartridge is #{cmd}"
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
    When "the application should #{before}"
  rescue Spec::Expectations::ExpectationNotMetError
    When "the application is #{after}"
  end
end
