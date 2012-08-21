# require 'rhc/version' #FIXME gem should know version
# FIXME Remove rubygems from requirements, ensure library is correct

# Only require external gem dependencies here
require 'rest_client'
require 'logger'

# Extend core methods
require 'rhc/core_ext'

module RHC
  autoload :Helpers,        'rhc/helpers'
  autoload :Rest,           'rhc/rest'
  autoload :HelpFormatter,  'rhc/help_formatter'
  autoload :CommandRunner,  'rhc/command_runner'
  autoload :Version,        'rhc/version'
  autoload :Commands,       'rhc/commands'
  autoload :Config,         'rhc/config'
end

require 'rhc/exceptions'

# Replace me with proper autoloads on the module RHC
require 'rhc-common'

