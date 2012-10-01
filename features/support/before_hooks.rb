Before('@sshkey') do
  Sshkey.remove "key1"
  Sshkey.remove "key2"
end

Before('@sshkey','@key1') do
  Given 'a new SSH key "key1.pub" is added as "key1"'
end

# Defined the required hooks first so we make sure we have everything we need
Before('@domain_required') do
  When 'we have an existing domain'
end

Before('@client_tools_required') do
  When 'we have the client tools setup'
end

Before('@single_cartridge','@init') do
  When 'an existing or new php-5.3 application without an embedded cartridge'
end

# These assumptions help to ensure any steps that are run independently have the same state as after the @init step
{
  :application => 'an existing or new php-5.3 application without an embedded cartridge',
  :scaled_application => 'an existing or new scaled php-5.3 application without an embedded cartridge',
  :domain => 'we have an existing domain',
  :client => 'we have the client tools setup',
  :single_cartridge => 'an existing or new php-5.3 application with an embedded mysql-5.1 cartridge',
  :multiple_cartridge => 'an existing or new php-5.3 application with embedded mysql-5.1 and phpmyadmin-3.4 cartridges',
}.each do |tag,assumption|
    Before("@#{tag}",'~@init') do
      When assumption
    end
  end
