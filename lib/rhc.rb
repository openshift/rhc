# require 'rhc/version' #FIXME gem should know version
# FIXME Remove rubygems from requirements, ensure library is correct

# Only require external gem dependencies here
require 'logger'
require 'pp'

require 'pry' if ENV['PRY']

# Extend core methods
require 'rhc/core_ext'

module RHC
  autoload :Auth,           'rhc/auth'
  autoload :CommandRunner,  'rhc/command_runner'
  autoload :Commands,       'rhc/commands'
  autoload :Config,         'rhc/config'
  autoload :Helpers,        'rhc/helpers'
  autoload :HelpFormatter,  'rhc/help_formatter'
  autoload :Rest,           'rhc/rest'
  autoload :TarGz,          'rhc/tar_gz'
  autoload :VERSION,        'rhc/version'
end

require 'rhc/exceptions'

