require 'benchmark'
require 'fileutils'

module RHCHelper
  module Commandify
    # Implements a method missing approach that will convert calls
    # like rhc_app_create into 'rhc app create' on the command line
    def method_missing(sym, *args, &block)
      if sym.to_s.start_with?("rhc")
        # Build up the command
        cmd = get_cmd(sym)

        # Get any blocks that should be run after processing
        cmd_callback = get_cmd_callback(cmd, args[0])

        # Add arguments to the command
        cmd << get_args(cmd, args[0])

        exitcode = nil
        # Run the command, timing it
        time = Benchmark.realtime do
          exitcode = run(cmd, args[0], &cmd_callback)
        end

        # if there is a callback let it take care of validating the results
        exitcode.should == 0 unless cmd_callback

        # Log the benchmarking info
        perf_logger.info "#{time} #{sym.to_s.upcase} #{$namespace} #{$login}"
      else
        super(sym, *args, &block)
      end
    end

    # Given a method name, convert to an equivalent
    # rhc command line string.  This method handles
    # exceptions like converting rhc_app_add_alias
    # to rhc app add-alias.
    def get_cmd(method_sym)
      cmd = method_sym.to_s.gsub('_', ' ')

      # Handle parameters with a dash
      cmd.gsub!('add alias', 'add-alias')
      cmd.gsub!('remove alias', 'remove-alias')
      cmd.gsub!('force stop', 'force-stop')

      return cmd
    end

    # Print out the command arguments based on the state of the application instance
    def get_args(cmd, arg0=nil, debug=true)
      args = " "
      args << "-l #{$username} "
      args << "-p #{$password} "
      args << "-d " if debug

      # Add the application name for all application commands
      if cmd =~ /app/
        raise "No application name" unless @name
        args << "-a #{@name} "
      end

      # Command specific arguments
      case cmd
        when /app delete/
          args << "--confirm "
        when /domain show/
          # domain show doesn't take arguments
        when /domain update/
          args << "#{$old_namespace} #{$namespace}"
        when /domain /
          raise "No namespace set" unless $namespace
          # use legacy switch for specifying namespace to verify older interface
          # should switch to using argument once all commands are moved over
          args << "#{$namespace} "
        when /snapshot/
          args << "-f #{@snapshot} "
        when /create/
          args << "-r #{@repo} "
          args << "-t #{@type} "
          args << "-s " unless @scalable.nil?
          args << "--noprompt "
        when /add-alias/
          raise "No alias set" unless @alias
          args << "--alias #{@alias} "
        when /cartridge/
          raise "No cartridge supplied" unless arg0
          args << "-c #{arg0}"
        when /sshkey/
          # in RHCHelper::Sshkey, we pass *args to method_missing here, so that
          # we _know_ that arg0 is an Array.
          args << arg0.first if arg0.first
      end

      args.rstrip
    end

    # This looks for a callback method that is defined for the command.
    # For example, a command with rhc_app_create_callback will match
    # and be returned for the 'rhc app create' command.  The most specific
    # callback will be matched, so rhc_app_create_callback being more
    # specific than rhc_app_callback.
    def get_cmd_callback(cmd, cartridge=nil)
      # Break the command up on spaces
      cmd_parts = cmd.split

      # Drop the 'rhc' portion from the array
      cmd_parts.shift

      # Look for a method match ending in _callback
      cmd_parts.length.times do
        begin
          # Look for a callback match and return on any find
          return method((cmd_parts.join("_") + "_callback").to_sym)
        rescue NameError
          # Remove one of the parts to see if there is a more
          # generic match defined
          cmd_parts.pop
        end
      end

      return nil
    end
  end

  #
  # Begin Post Processing Callbacks
  #
  def app_create_callback(exitcode, stdout, stderr, arg)
    match = stdout.match(UUID_OUTPUT_PATTERN)
    @uid = match[1] if match
    raise "UID not parsed from app create output" unless @uid
    persist
  end

  def app_destroy_callback(exitcode, stdout, stderr, arg)
    FileUtils.rm_rf @repo
    FileUtils.rm_rf @file
    @repo, @file = nil
  end

  def cartridge_add_callback(exitcode, stdout, stderr, cartridge)
    if cartridge.start_with?('mysql-')
      @mysql_hostname = /^Connection URL: mysql:\/\/(.*)\/$/.match(stdout)[1]
      @mysql_user = /^ +Root User: (.*)$/.match(stdout)[1]
      @mysql_password = /^ +Root Password: (.*)$/.match(stdout)[1]
      @mysql_database = /^ +Database Name: (.*)$/.match(stdout)[1]

      @mysql_hostname.should_not be_nil
      @mysql_user.should_not be_nil
      @mysql_password.should_not be_nil
      @mysql_database.should_not be_nil
    end

    @embed << cartridge
    persist
  end

  def cartridge_remove_callback(exitcode, stdout, stderr, cartridge)
    @mysql_hostname = nil
    @mysql_user = nil
    @mysql_password = nil
    @mysql_database = nil
    @embed.delete(cartridge)
    persist
  end

  def domain_callback(exitcode, stdout, stderr, arg)
    @domain_output = stdout
  end

  def domain_show_callback(exitcode, stdout, stderr, arg)
    @domain_show_output = stdout
  end

  def domain_create_callback(exitcode, stdout, stderr, arg)
    @exitcode = exitcode
  end
  
  def domain_update_callback(exitcode, stdout, stderr, arg)
    @exitcode = exitcode
  end

  def domain_delete_callback(exitcode, stdout, stderr, arg)
    @exitcode = exitcode
  end

  def sshkey_callback(exitcode, stdout, stderr, arg)
    @sshkey_output = stdout
    @exitcode = exitcode
  end
  
  def sshkey_add_callback(exitcode, stdout, stderr, arg)
    @sshkey_output = stdout
    @exitcode = exitcode
  end

  def sshkey_list_callback(exitcode, stdout, stderr, arg)
    @sshkey_output = stdout
    @exitcode = exitcode
  end

  def sshkey_show_callback(exitcode, stdout, stderr, arg)
    @sshkey_output = stdout
    @exitcode = exitcode
  end
  
  def sshkey_update_callback(exitcode, stdout, stderr, arg)
    @sshkey_output = stdout
    @exitcode = exitcode
  end

  def sshkey_delete_callback(exitcode, stdout, stderr, arg)
    @sshkey_output = stdout
    @exitcode = exitcode
  end

end
