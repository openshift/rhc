source :rubygems

gemspec

gem 'simplecov', :require => false, :group => :test

# Fedora 17 splits bigdecimal out into its own gem.  No other platform has bigdecimal as a gem.
unless Gem::Specification.respond_to?(:find_all_by_name) and Gem::Specification::find_all_by_name('bigdecimal').empty?
  gem 'bigdecimal', :require => false, :group => :test
end
