require 'rubygems'
require 'active_support/ordered_hash'
require 'tmpdir'

### Some shared constant declarations
module RHCHelper
  TEMP_DIR = File.join(Dir.tmpdir, "rhc") unless const_defined?(:TEMP_DIR)
  # The regex to parse the UUID output from the create app results
  UUID_OUTPUT_PATTERN = %r|UUID\s*=\s*(.+)| unless const_defined?(:UUID_OUTPUT_PATTERN)
  # The regex to parse the Gear Profile output from the create app results
  GEAR_PROFILE_OUTPUT_PATTERN = %r|Application Info.*Gear Size\s*=\s*(\w+)|m unless const_defined?(:GEAR_PROFILE_OUTPUT_PATTERN)
  # Regex to parse passwords out of logging messages
  PASSWORD_REGEX = / -p [^\s]* / unless const_defined?(:PASSWORD_REGEX)
end

require 'rhc_helper/loggable'
require 'rhc_helper/commandify'
require 'rhc_helper/httpify'
require 'rhc_helper/persistable'
require 'rhc_helper/runnable'
require 'rhc_helper/app'
require 'rhc_helper/domain'
require 'rhc_helper/sshkey'
