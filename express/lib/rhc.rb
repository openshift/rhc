# require 'rhc/version' #FIXME gem should know version
# FIXME Remove rubygems from requirements, ensure library is correct

# Only require external gem dependencies here
require 'rest-client'
require 'logger'

module RHC
end

# Replace me with proper autoloads on the module RHC
require 'rhc-common'
require 'rhc-rest'

