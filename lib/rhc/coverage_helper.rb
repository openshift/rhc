if RUBY_VERSION >= '1.9' and ENV['RHC_FEATURE_COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    coverage_dir 'coverage/features/'

    # Filters - these files will be ignored.
    add_filter 'lib/rhc/vendor/'   # vendored files should be taken directly and only
                                   # namespaces changed
    add_filter 'features/'         # Don't report on the files that run the cucumber tests
    add_filter 'lib/rhc-feature-coverage-helper.rb'
    add_filter 'spec/'             # Don't report on the files that run the spec tests

    # Groups - general categories of test areas
    add_group('Commands') { |src_file| src_file.filename.include?(File.join(%w[lib rhc commands])) }
    add_group('RHC Lib')  { |src_file| src_file.filename.include?(File.join(%w[lib rhc])) }
    add_group('REST')     { |src_file| src_file.filename.include?(File.join(%w[lib rhc-rest])) }  
    add_group('Legacy')   { |src_file| src_file.filename.include?(File.join(%w[bin])) or
                                       src_file.filename.include?(File.join(%w[lib rhc-common.rb])) }
    add_group('Test')     { |src_file| src_file.filename.include?(File.join(%w[features])) or
                                       src_file.filename.include?(File.join(%w[spec])) }

    use_merging = true
    # Note, the #:nocov: coverage exclusion  should only be used on external functions 
    #  that cannot be nondestructively tested in a developer environment.
  end
end
