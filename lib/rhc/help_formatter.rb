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

  class CommandHelpBindings
    def initialize(command, instance_commands, runner)
      @command = command
      @actions = instance_commands.collect do |command_name, command_class|
        next if command_class.summary.nil?
        m = /^#{command.name} ([^ ]+)/.match(command_name)
        # if we have a match and it is not an alias then we can use it
        m and command_name == command_class.name ? {:name => m[1], :summary => command_class.summary || ""} : nil
      end
      @actions.compact!
      @global_options = runner.options
      @runner = runner
    end
    def program(*args)
      @runner.program *args
    end
  end
end
