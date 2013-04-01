require 'rhc'
require 'rhc/commands'

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
      $terminal.wrap_at = HighLine::SystemExtensions.terminal_size.first rescue 80 if $stdin.tty?
      $terminal.page_at = :auto if $stdin.tty? and $stdout.tty?
      # FIXME: ANSI terminals are not default on windows but we may just be
      #        hitting a bug in highline if windows does support another method.
      #        This is a safe fix for now but needs more research.
      HighLine::use_color = false if RHC::Helpers.windows? or not $stdout.tty?
    end

    def self.start(args)
      runner = RHC::CommandRunner.new(args)
      Commander::Runner.instance_variable_set :@singleton, runner

      program :name,           'rhc'
      program :description,    'Command line interface for OpenShift.'
      program :version,        RHC::VERSION::STRING
      program :help_formatter, RHC::HelpFormatter
      program :int_message,    " Interrupted\n"

      RHC::Commands.load.to_commander
      run! || 0
    end
  end
end
