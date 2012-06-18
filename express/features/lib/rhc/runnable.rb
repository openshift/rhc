require 'open4'
require 'timeout'

module RHCHelper
  module Runnable
    include Loggable

    def run(cmd, arg=nil)
      logger.info("Running: #{cmd}")

      exit_code = -1
      output = nil

      # Don't let a command run more than 5 minutes
      Timeout::timeout(500) do
        pid, stdin, stdout, stderr = Open4::popen4 cmd
        stdin.close

        # Block until the command finishes
        ignored, status = Process::waitpid2 pid
        out = stdout.read.strip
        err = stderr.read.strip
        stdout.close
        stderr.close
        logger.debug("Standard Output:\n#{out}")
        logger.debug("Standard Error:\n#{err}")

        # Allow a caller to pass in a block to process the output
        yield status.exitstatus, out, err, arg if block_given?
        exit_code = status.exitstatus
      end

      if exit_code != 0
        logger.error("(#{$$}): Execution failed #{cmd} with exit_code: #{exit_code.to_s}")
      end

      return exit_code
    end
  end
end
