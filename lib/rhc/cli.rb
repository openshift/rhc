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

    extend Commander::Delegates

    def self.set_terminal
      $terminal.wrap_at = HighLine::SystemExtensions.terminal_size.first - 5 rescue 80 if $stdin.tty?
    end

    def self.start(args)
      runner = Commander::Runner.new(args)
      Commander::Runner.instance_variable_set :@singleton, runner

      program :name,        'rhc'
      program :version,     '0.0.0' #FIXME pull from versions.rb
      program :description, 'Command line interface for OpenShift.'
      program :help_formatter, :compact

      RHC::Commands.load.to_commander
      exit(run! || 0)
    end
  end
end
