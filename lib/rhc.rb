# require 'rhc/version' #FIXME gem should know version
# FIXME Remove rubygems from requirements, ensure library is correct

# Only require external gem dependencies here
require 'rest_client'
require 'logger'

# Extend core methods
require 'rhc/core_ext'
require 'rhc/version'

module RHC
  module Commands; end

  autoload :Helpers,  'rhc/helpers'
end

# Replace me with proper autoloads on the module RHC
require 'rhc-common'
require 'rhc-rest'

