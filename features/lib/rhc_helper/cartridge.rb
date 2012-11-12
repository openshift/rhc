require 'rhc/rest'

module RHCHelper
  #
  # A class to help maintain the state from rhc calls and helper
  # methods around cartridge management.
  #
  class Cartridge
    extend Runnable
    extend Commandify
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
      @app_name = app.name unless app.nil?
      @hostname = "#{@app_name}-#{$namespace}.#{$domain}"
      @file = "#{TEMP_DIR}/#{$namespace}.json"
    end

    def rhc_cartridge(cmd)
      full_cmd = "rhc cartridge #{cmd} -l #{$username} -p #{$password} #{@app_name ? "-a #{@app_name}" : ""}"
      full_cmd += " #{@name}" if cmd != "list"
      run(full_cmd, nil) do |exitstatus, out, err, arg|
        yield exitstatus, out, err, arg if block_given?
      end
    end

    def self.list
      rhc_cartridge_list do |exitstatus, out, err, arg|
        return [exitstatus, out, err, arg]
      end
    end

    def add
      rhc_cartridge('add') do |exitstatus, out, err, arg|
        yield exitstatus, out, err, arg if block_given?
      end
    end

    def status
      result = ""
      rhc_cartridge('status') do |exitstatus, out, err, arg|
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
      rhc_cartridge('remove --confirm')
    end

    def scale(values)
      status = nil
      rhc_cartridge("scale #{values}") do |exitstatus, out, err, arg|
        status = exitstatus
      end
      status
    end

    def show
      result = ""
      rhc_cartridge('show') do |exitstatus, out, err, arg|
        result = out
      end
      result
    end
  end
end
