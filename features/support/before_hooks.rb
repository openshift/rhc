# Defined the required hooks first so we make sure we have everything we need
Before('@domain_required') do
  step 'we have an existing domain'
end

Before('@client_tools_required') do
  step 'we have the client tools setup'
end

Before('@single_cartridge','@init') do
  step 'an existing or new php-5.3 application without an embedded cartridge'
end

# These assumptions help to ensure any steps that are run independently have the same state as after the @init step
{
  :application => 'an existing or new php-5.3 application without an embedded cartridge',
  :domain => 'we have an existing domain',
  :client => 'we have the client tools setup',
  :single_cartridge => 'an existing or new php-5.3 application with an embedded mysql-5.1 cartridge',
  :multiple_cartridge => 'an existing or new php-5.3 application with embedded mysql-5.1 and phpmyadmin-3.4 cartridges',
}.each do |tag,assumption|
  Before("@#{tag}",'~@init') do
    step assumption
  end
end
