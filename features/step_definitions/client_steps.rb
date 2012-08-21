require 'rhc/wizard'

# Cross-platform way of finding an executable in the $PATH.
#
#   which('ruby') #=> /usr/bin/ruby
#
#   Solution found at: http://bit.ly/8dKQsa
#
def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each { |ext|
      exe = "#{path}/#{cmd}#{ext}"
      return exe if File.executable? exe
    }
  end
  return nil
end

Given /^the libra client tools$/ do
  which('rhc').should_not be_nil
end

When /^the setup wizard is run$/ do
  RHCHelper::App.rhc_setup

  # Force a refresh of the loaded RHC state
  RHC::Config.initialize
end

Then /^the client tools should be setup$/ do
  (RHC::Config.has_local_config? or RHC::Config.has_opts_config?).should be_true, "Wizard still thinks it needs to be run"
end

