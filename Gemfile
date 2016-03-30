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

# Limit net-ssh when using older versions of ruby
# See https://bugzilla.redhat.com/show_bug.cgi?id=1197301 for the 2.9.2 limit
if RUBY_VERSION < '2.0'
  gem "net-ssh", "<= 2.9.2"
else
  gem "net-ssh", ">= 3.0.0"
end

# Limits addressable for Ruby 1.8.7
if RUBY_VERSION < '1.9'
  gem "addressable", "< 2.4.0"
end

# Latest versions of these gems do not support ruby_18
gem "rake", "< 10.1.2"
gem "i18n", "< 0.7.0"
gem "commander", "< 4.3.0"
