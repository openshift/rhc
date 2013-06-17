require 'commander/help_formatters/base'

module RHC
  class HelpFormatter < Commander::HelpFormatter::Terminal
    def template(name)
      ERB.new(File.read(File.join(File.dirname(__FILE__), 'usage_templates', "#{name}.erb")), nil, '-')
    end
    def render
      template(:help).result RunnerHelpBindings.new(@runner).get_binding
    end
    def render_command_syntax command
      template(:command_syntax_help).result command.get_binding
    end
    def render_options runner
      template(:options_help).result RunnerHelpBindings.new(runner).get_binding
    end
  end

  class RunnerHelpBindings < SimpleDelegator
    include RHC::Helpers

    def commands
      __getobj__.instance_variable_get(:@commands)
    end

    def get_binding
      binding
    end
  end

  class CommandHelpBindings
    include RHC::Helpers

    def initialize(command, instance_commands, runner)
      @command = command
      @actions = 
        if command.root?
          instance_commands.collect do |command_name, command_class|
            next if command_class.summary.nil?
            m = /^#{command.name}[\-]([^ ]+)/.match(command_name)
            # if we have a match and it is not an alias then we can use it
            m and command_name == command_class.name ? {:name => m[1], :summary => command_class.summary || ""} : nil
          end
        else
          []
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
