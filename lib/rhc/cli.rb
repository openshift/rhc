require 'rhc'
require 'commander'
require 'commander/runner'
require 'commander/delegates'
require 'rhc/commands'
require 'rhc/help_formatter'

include Commander::UI
include Commander::UI::AskForClass

module RHC
  #
  # Run and execute a command line session with the RHC tools.
  #
  # You can invoke the CLI with:
  #   bundle exec ruby -e 'require "rhc/cli"; RHC::CLI.start(ARGV);' -- <arguments>
  #
  # from the gem directory.
  #
  module CLI
    class Runner < Commander::Runner
      # override so we can catch InvalidCommandError
      def run_active_command
        super
      rescue InvalidCommandError => e
        usage = RHC::UsageHelpFormatter.new(self).render
        abort "Invalid rhc resource: #{@args[0]}\n#{usage}"
      end
    end

    extend Commander::Delegates

    def self.set_terminal
      $terminal.wrap_at = HighLine::SystemExtensions.terminal_size.first - 5 rescue 80 if $stdin.tty?
    end

    def self.start(args)
      runner = Runner.new(args)
      Commander::Runner.instance_variable_set :@singleton, runner

      program :name,        'rhc'
      program :version,     RHC::VERSION::STRING
      program :description, 'Command line interface for OpenShift.'
      program :help_formatter, RHC::UsageHelpFormatter

      RHC::Commands.load.to_commander
      exit(run! || 0)
    end
  end
end
