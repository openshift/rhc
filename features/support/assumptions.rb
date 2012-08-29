Given 'we have the client tools setup' do
  Given 'the libra client tools'
  And 'the client tools should be setup if needed'
end

Given 'we have an existing domain' do
  Given 'we have the client tools setup'
  And 'a new domain is needed and created'
end

Given /^we have a running (.*) application(.*?)$/ do |type,embed|
  Given 'we have an existing domain'
  And "an existing or new #{type} application#{embed}"
end
