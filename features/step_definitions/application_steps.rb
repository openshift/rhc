require 'fileutils'
require 'rhc/config'

include RHCHelper

# This can transform any application cartridge requirements into an array
Transform /^application with(.*)$/ do |embed_type|
  case embed_type.strip
  when /^out an embedded cartridge/
    []
  when /^an embedded (.*) cartridge$/
    [$1]
  when /^embedded (.*) and (.*) cartridges$/
    [$1,$2]
  end
end

# Use the transformed array so we can reuse this step for all combinations
Given /^an existing (or new )?(scaled )?(.+) (application with.*)$/ do |create, scaled, type, embeds|
  options = { :type => type }
  options[:embed] = embeds if embeds
  options[:scalable] = scaled if scaled
  @app = App.find_on_fs(options)

  @app = nil if @app.nil? or not @app.is_created?

  if create && @app.nil?
    step "a #{scaled}#{type} application is created"
    embeds.each do |embed|
      step "the #{embed} cartridge is added"
    end
  end

  @app.should_not be_nil, "No existing %s applications %sfound.  Check the creation scenarios for failures." % [
    type,
    embeds ? '' : "w/ [#{embeds.join(',')}]"
  ]
end

# Mark this step as pending so we make sure to explicitly require apps without embeds
Given /^an existing (or new )?(.+) application$/ do |create,type|
  pending
end

When /^(\d+) (.+) applications are created$/ do |app_count, type|
  old_app = @app
  @apps = app_count.to_i.times.collect do
    step "a #{type} application is created"
    @app
  end
  @app = old_app
end

When /^a (scaled )?(.+) application is created(?: with a (.*) gear)?$/ do |scaled, type, gear_profile|
  @app = App.create_unique(type, scaled, gear_profile)
  @app.rhc_app_create
end

When /^the application is (\w+)$/ do |command|
  # Do any pre-check setup we may need
  case command
  when 'snapshot'
    @snapshot = File.join(RHCHelper::TEMP_DIR, "snapshot.tar.gz")
    @app.snapshot = @snapshot
  end

  # Set up aliases for any irregular commands
  aliases = {
    :stopped => :stop,
    :shown   => :show,
    :tidied  => :tidy,
    :snapshot => :snapshot_save,
    :deleted => :delete
  }

  # Use an alias if it exists, or just remove 'ed' (like from started)
  cmd = aliases[command.to_sym] || command.gsub(/ed$/,'').to_sym

  # Send the specified command to the application
  @app.send("rhc_app_#{cmd}")
end

Then /^the snapshot should be found$/ do
  File.exist?(@snapshot).should be_true
  (File.size(@snapshot) > 0).should be_true
end

Then /^the applications should be accessible?$/ do
  old_app = @app
  @apps.each do |app|
    step "the application should be accessible"
  end
  @app = old_app
end

Then /^the application should be accessible$/ do
  @app.is_accessible?.should be_true
  @app.is_accessible?({:use_https => true}).should be_true, "Application was not accessible and should be"
end

Then /^the application should not be accessible$/ do
  @app.is_inaccessible?.should be_true, "Application was still accessible when it shouldn't be"
end

Then /^the application should not exist$/ do
  @app.doesnt_exist?.should be_true, "Application still exists when it shouldn't"
end

Then /^it should succeed$/ do
end

Then /^the application should be scalable/ do
  step "the haproxy-1.4 cartridge should be running"
end

Then /^the application should have a (.*) gear$/ do |gear_profile|
  @app.gear_profile.should match("#{gear_profile}")
end
