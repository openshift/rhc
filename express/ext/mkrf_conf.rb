## Add some testing for when we are building a rpm and when we're not
msg = ''

unless ENV['RHC_RPMBUILD']
  require 'rubygems'
  require 'rubygems/command.rb'
  require 'rubygems/dependency_installer.rb' 
  require 'rubygems/uninstaller.rb'
  begin
    Gem::Command.build_args = ARGV
  rescue NoMethodError
  end 
  inst = Gem::DependencyInstaller.new
  begin
    if RUBY_VERSION > "1.9"
      inst.install "test-unit"
    end

    # Attempt native json installation (unless JSON_PURE is specified)
    #   - fall back to json_pure if it fails
    #   - Known failure conditions
    #     - Ubuntu: using ruby and not ruby-dev
    begin
      throw if ENV['JSON_PURE']
      inst.install('json')
    rescue
      inst.install('json_pure')
    end

  rescue
    exit(1)
  end 

  # Remove rhc-rest if it's installed
  begin
    Gem::Uninstaller.new('rhc-rest').uninstall

    # This only gets printed if verbose is specified 
    #   TODO: Need to figure out how to get it always shown
    msg = <<-MSG
      ===================================================
        rhc-rest is no longer needed as an external gem
          - If it is installed, it will be removed
          - Its libraries are now included in rhc
            - Any applications requiring rhc-rest will 
              still function as expected
      ===================================================
    MSG
  rescue Gem::LoadError,Gem::InstallError
    # This means that rhc-rest was not installed, not a problem
  end
end

f = File.open(File.join(File.dirname(__FILE__), "Rakefile"), "w")   # create dummy rakefile to indicate success
f.write("task :default do\n")
f.write("\tputs '%s'\n" % msg) if msg
f.write("end\n")
f.close
