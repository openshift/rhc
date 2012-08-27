require 'fileutils'
require 'rhc/config'

include RHCHelper

Given /^an existing (or new )?(.+) application with an embedded (.*) cartridge$/ do |create,type,embed|
  @app = App.find_on_fs(type).find do |app|
    app.embed.include?(embed)
  end

  if create && @app.nil?
    Then "a #{type} application is created"
    And "the #{embed} cartridge is added"
  end

  @app.should_not be_nil, 'No existing applications w/cartridges found.  Check the creation scenarios for failures.'
end

Given /^an existing (or new )?(.+) application with embedded (.*) and (.*) cartridges$/ do |create,type, embed_1, embed_2|
  embeds = [embed_1,embed_2]
  @app = App.find_on_fs(type).find do |app|
    [app.embed & embeds ] == embeds
  end

  if create && @app.nil?
    Then "a #{type} application is created"
    embeds.each do |embed|
      And "the #{embed} cartridge is added"
    end
  end

  @app.should_not be_nil, 'No existing applications w/cartridges found.  Check the creation scenarios for failures.'
end

Given /^an existing (or new )?(.+) application without an embedded cartridge$/ do |create,type|
  @app = App.find_on_fs(type).find do |app|
    app.embed.empty?
  end

  if create && @app.nil?
    Then "a #{type} application is created"
  end

  @app.should_not be_nil, 'No existing applications found.  Check the creation scenarios for failures.'
end

Given /^an existing (or new )?(.+) application$/ do |create,type|
  @app = App.find_on_fs(type).first

  if create && @app.nil?
    Then "a #{type} application is created"
  end

  @app.should_not be_nil, 'No existing applications found.  Check the creation scenarios for failures.'
end

When /^(\d+) (.+) applications are created$/ do |app_count, type|
  old_app = @app
  @apps = app_count.to_i.times.collect do
    Then "a #{type} application is created"
    @app
  end
  @app = old_app
end

When /^a (.+) application is created$/ do |type|
  @app = App.create_unique(type)
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
    :snapshot => :snapshot_save
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
  @apps.each do |app|
    app.is_accessible?.should be_true
    app.is_accessible?({:use_https => true}).should be_true
  end
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
