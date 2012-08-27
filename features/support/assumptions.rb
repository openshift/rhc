Given 'we have the client tools setup' do
  Given 'the libra client tools'
  And 'the setup wizard is run'
  And 'the client tools should be setup'
end

Given 'we have an existing domain' do
  Given 'we have the client tools setup'
  And 'a new domain is needed and created'
  And 'the domain should be reserved'
end

Given /^we have a running php-5.3 application(.*?)$/ do |embed|
  Given 'we have an existing domain'
  And "an existing or new php-5.3 application#{embed}"
end
