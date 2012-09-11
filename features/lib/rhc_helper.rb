require 'rubygems'
require 'active_support/ordered_hash'
require 'tmpdir'

### Some shared constant declarations
module RHCHelper
  TEMP_DIR = File.join(Dir.tmpdir, "rhc") unless const_defined?(:TEMP_DIR)
  # The regex to parse the ssh output from the create app results
  SSH_OUTPUT_PATTERN = %r|ssh://([^@]+)@([^/]+)| unless const_defined?(:SSH_OUTPUT_PATTERN)
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