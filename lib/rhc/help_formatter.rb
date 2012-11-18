require 'commander/help_formatters/base'

module RHC
  class HelpFormatter < Commander::HelpFormatter::Terminal
    def template(name)
      ERB.new(File.read(File.join(File.dirname(__FILE__), 'usage_templates', "#{name}.erb")), nil, '-')
    end
    def render_command_syntax command
      template(:command_syntax_help).result command.get_binding
    end
  end
  # TODO: class ManPageHelpFormatter
end
