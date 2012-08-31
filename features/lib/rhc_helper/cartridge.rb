require 'rhc/rest'

module RHCHelper
  #
  # A class to help maintain the state from rhc calls and helper
  # methods around cartridge management.
  #
  class Cartridge
    extend Runnable
    extend Persistable
    include Loggable
    include Runnable
    include Httpify
    include Persistify

    # attributes to represent the general information of the cartridge
    attr_accessor :name

    # Create the data structure for a test cartridge
    def initialize(app, name)
      @name = name
      @app_name = app.name
      @hostname = "#{@app_name}-#{$namespace}.#{$domain}"
      @file = "#{TEMP_DIR}/#{$namespace}.json"
    end

    def legacy_rhc_app_cartridge(cmd)
      full_cmd = "rhc app cartridge #{cmd} -l #{$username} -p #{$password} -a #{@app_name}"
      full_cmd += " -c #{@name}" if cmd != "list"
      run(full_cmd, nil) do |exitstatus, out, err, arg|
        yield exitstatus, out, err, arg if block_given?
      end
    end

    def rhc_cartridge(cmd)
      full_cmd = "rhc cartridge #{cmd} -l #{$username} -p #{$password} -a #{@app_name}"
      full_cmd += " #{@name}" if cmd != "list"
      run(full_cmd, nil) do |exitstatus, out, err, arg|
        yield exitstatus, out, err, arg if block_given?
      end
    end

    def add
      rhc_cartridge('add') do |exitstatus, out, err, arg|
        yield exitstatus, out, err, arg if block_given?
      end
    end

    def status
      result = ""
      legacy_rhc_app_cartridge('status') do |exitstatus, out, err, arg|
        result = out
      end

      result
    end

    def start
      rhc_cartridge('start')
    end

    def stop
      rhc_cartridge('stop')
    end

    def restart
      rhc_cartridge('restart')
    end

    def remove
      rhc_cartridge('remove')
    end
  end
end
