unless RUBY_VERSION < '1.9'
  require 'simplecov'

  original_stderr = $stderr # in case helpers don't properly cleanup
  original_stdout = $stdout

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

    def print_missed_lines
      @files.each do |file|
        file.missed_lines.each do |line|
          original_stdout.puts "MISSED #{file.filename}:#{line.number}"
        end
      end
    end
  end

  SimpleCov.at_exit do
    SimpleCov.result.format!
    if SimpleCov.result.covered_percent < 100.0
      SimpleCov.result.print_missed_lines if SimpleCov.result.covered_percent > 98.0
      original_stderr.puts "Coverage not 100%, build failed."
      exit 1
    end
  end

  SimpleCov.start do
    coverage_dir 'coverage/spec/'

    # Filters - these files will be ignored.
    add_filter 'lib/rhc/vendor/'   # vendored files should be taken directly and only
                                   # namespaces changed
    add_filter 'lib/rhc/rest/'     # REST coverage is not yet 100%
    add_filter 'lib/bin/'          # This is just for safety; simplecov isn't picking these up.
    add_filter 'features/'         # Don't report on the files that run the cucumber tests
    add_filter 'lib/rhc-feature-coverage-helper.rb'
    add_filter 'spec/'             # Don't report on the files that run the spec tests

    # Groups - general categories of test areas
    add_group('Commands') { |src_file| src_file.filename.include?(File.join(%w[lib rhc commands])) }
    add_group('RHC Lib')  { |src_file| src_file.filename.include?(File.join(%w[lib rhc])) }
    add_group('REST')     { |src_file| src_file.filename.include?(File.join(%w[lib rhc/rest])) }
    add_group('Test')     { |src_file| src_file.filename.include?(File.join(%w[features])) or
                                       src_file.filename.include?(File.join(%w[spec])) }

    # Note, the #:nocov: coverage exclusion  should only be used on external functions
    #  that cannot be nondestructively tested in a developer environment.
  end
end
