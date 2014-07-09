source 'https://rubygems.org'

gemspec

gem 'pry' if ENV['PRY']

gem 'simplecov', :require => false, :group => :test

# Fedora 17 splits bigdecimal out into its own gem.  No other platform has bigdecimal as a gem.
if Gem::Specification.respond_to?(:find_all_by_name) and not Gem::Specification::find_all_by_name('bigdecimal').empty?
  gem 'bigdecimal', :require => false, :group => :test
end

# Fedora 19 splits psych out into its own gem.
if Gem::Specification.respond_to?(:find_all_by_name) and not Gem::Specification::find_all_by_name('psych').empty?
  gem 'psych'
end

# Rake 10.1.2 does not support ruby_18
gem "rake", "< 10.1.2"