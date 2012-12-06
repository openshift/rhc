Before('@clean') do
  puts "Cleaning applications and keys now"
  clean_applications(true)
end

Before('@sshkey') do
  Sshkey.remove "key1"
  Sshkey.remove "key2"
end

Before('@sshkey','@key1') do
  step 'a new SSH key "key1.pub" is added as "key1"'
end

# Defined the required hooks first so we make sure we have everything we need
Before('@geared_user_required') do
  $old_username = $username
  $old_namespace = nil
  $username = "user_with_multiple_gear_sizes@test.com"
  $namespace = nil
end
After do
  $username = $old_username if $old_username
  $namespace = $old_namespace if $old_namespace
  $old_username = nil
  $old_namespace = nil
end

Before('@cartridge_storage_user_required') do
  $old_username = $username
  $username = "user_with_extra_storage@test.com"
end

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
  :scaled_application => 'an existing or new scaled php-5.3 application without an embedded cartridge',
  :domain => 'we have an existing domain',
  :client => 'we have the client tools setup',
  :single_cartridge => 'an existing or new php-5.3 application with an embedded mysql-5.1 cartridge',
  :multiple_cartridge => 'an existing or new php-5.3 application with embedded mysql-5.1 and phpmyadmin-3.4 cartridges',
}.each do |tag,assumption|
    Before("@#{tag}",'~@init') do
      step assumption
    end
  end
