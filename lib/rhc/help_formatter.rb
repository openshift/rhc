require 'commander/help_formatters/base'

module RHC
  class UsageHelpFormatter < Commander::HelpFormatter::Base
    def render
      # TODO: render the rhc usage when we move 100% to using Commander
      "rhc"
    end

    def render_command command
      #TODO: generate list of command line switches
      program = @runner.program_defaults
      <<USAGE
Usage: #{program[:name]} #{command.name}
#{command.summary}

List of arguments
  -l|--rhlogin      rhlogin      Red Hat login (RHN or OpenShift login)
  -p|--password     password     RHLogin password (optional, will prompt)
  -c|--config       path         Path of alternate config file
USAGE
    end
  end

  # TODO: class ManPageHelpFormatter
end
