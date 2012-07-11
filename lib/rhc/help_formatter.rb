require 'commander/help_formatters/base'

module RHC
  class UsageHelpFormatter < Commander::HelpFormatter::Base
    def global_options_output
      result = "Global Options:\n"
      @runner.options.each { |o|
        result += o[:switches].join('|')
        result += "\t#{o[:description]}\n"
      }
      result
    end

    def render
      # TODO: render the rhc usage when we move 100% to using Commander
      result = "#{@runner.program(:name)} - #{@runner.program(:description)}\n\n"
      result += global_options_output
      result
    end

    def render_command command
      result = ""
      result = "Usage: #{@runner.program(:name)} #{command.name}\n"
      result += "#{command.summary}\n\n"
      result += global_options_output
    end
  end

  # TODO: class ManPageHelpFormatter
end
