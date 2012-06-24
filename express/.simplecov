#
# Conditionally requires simplecov if it is available.  If available, coverage
# less than 100% will fail the build.
#
# Patch to get correct coverage count, filed 
# https://github.com/colszowka/simplecov/issues/146 upstream.
class SimpleCov::Result
  def missed_lines
    return @missed_lines if defined? @missed_lines
    @missed_lines = 0
    @files.each do |file|
      @missed_lines += file.missed_lines.count
    end
    @missed_lines
  end
end

SimpleCov.start do
  add_filter  'lib/rhc-rest.rb'    # temporarily disabled until test coverage can be added.
  add_filter  'lib/rhc/vendor/'    # vendored files should be taken directly and only
                                  #   namespaces changed
  add_filter  'lib/rhc-rest/'      # temporary

  add_group   'Commands', 'lib/rhc/commands/'

  add_filter  'lib/rhc-common.rb'  # deprecated, functionality moved into client or rhc/helpers.rb
  add_filter  'lib/helpers.rb'     # deprecated, will be replaced by rhc/helpers.rb
  add_group   'Legacy',   'bin/'
  add_group   'Legacy',   'lib/rhc-common.rb'
  add_group   'Legacy',   'lib/helpers.rb'

  add_filter  'features/'
  add_filter  'spec/'
  add_group   'Test',   'features/'
  add_group   'Test',   'spec/'

  # Note, the #:nocov: coverage exclusion  should only be used on external functions 
  #  that cannot be nondestructively tested in a developer environment.
end
