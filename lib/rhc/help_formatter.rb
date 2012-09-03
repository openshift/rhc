require 'commander/help_formatters/base'

module RHC
  class HelpFormatter < Commander::HelpFormatter::Terminal
    def template(name)
      ERB.new(File.read(File.join(File.dirname(__FILE__), 'usage_templates', "#{name}.erb")), nil, '-')
    end
  end
  # TODO: class ManPageHelpFormatter
end
