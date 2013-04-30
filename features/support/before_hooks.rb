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
  $username = "user_with_multiple_gear_sizes@test.com"
  $namespace = nil

  if !$cleaned_gears
    clean_applications($username)
    $cleaned_gears = true
  end
end

Before('@certificates_capable_user_required') do
  $old_username = $username
  $username = "user_with_certificate_capabilities@test.com"
  $namespace = nil

  if !$cleaned_certificates
    clean_applications($username)
    $cleaned_certificates = true
  end
end

After do
  if $old_username
    $username = $old_username
    $namespace = nil
    $old_username = nil
    $old_namespace = nil
  end
end

Before('@cartridge_storage_user_required') do
  $old_username = $username
  $username = "user_with_extra_storage@test.com"
  $namespace = nil

  if !$cleaned_storage
    clean_applications($username)
    $cleaned_storage = true
  end
end

Before('@clean') do
  clean_applications($username, true)
end

Before('@domain_required') do
  step 'we have an existing domain'
end

Before('@client_tools_required') do
  step 'we have the client tools setup'
end

Before('@single_cartridge','@init') do
  step "an existing or new php application without an embedded cartridge"
end

# These assumptions help to ensure any steps that are run independently have the same state as after the @init step
{
  :application => "an existing or new php application without an embedded cartridge",
  :scaled_application => "an existing or new scaled php application without an embedded cartridge",
  :domain => 'we have an existing domain',
  :client => 'we have the client tools setup',
  :single_cartridge => "an existing or new php application with an embedded mysql cartridge",
  :multiple_cartridge => "an existing or new php application with embedded mysql and phpmyadmin cartridges",
}.each do |tag,assumption|
    Before("@#{tag}",'~@init') do
      step assumption
    end
  end