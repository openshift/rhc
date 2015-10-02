source 'https://rubygems.org'

gemspec

if ENV['PRY']
  gem 'pry' 
  gem 'pry-debugger'
end

gem 'simplecov', :require => false, :group => :test

# Fedora 17 splits bigdecimal out into its own gem.  No other platform has bigdecimal as a gem.
if Gem::Specification.respond_to?(:find_all_by_name) and not Gem::Specification::find_all_by_name('bigdecimal').empty?
  gem 'bigdecimal', :require => false, :group => :test
end

# Fedora 19 splits psych out into its own gem.
if Gem::Specification.respond_to?(:find_all_by_name) and not Gem::Specification::find_all_by_name('psych').empty?
  gem 'psych'
end

# See https://bugzilla.redhat.com/show_bug.cgi?id=1197301
gem "net-ssh", "<= 2.9.2"

# Latest versions of these gems do not support ruby_18
gem "rake", "< 10.1.2"
gem "i18n", "< 0.7.0"
gem "commander", "< 4.3.0"
