require 'rhc'
require 'commander'
require 'commander/runner'
require 'commander/delegates'
require 'rhc/commands'

module RHC
  class AutoCompleteBindings
    attr_reader :top_level_opts, :commands
    def initialize(top_level_opts, commands)
      @top_level_opts = top_level_opts
      @commands = commands
    end
  end

  class AutoComplete
    def initialize(script="rhc")
      @script_erb = ERB.new(File.read(File.join(File.dirname(__FILE__), 'autocomplete_templates', "#{script}.erb")), nil, '-')
      cli_init
      # :name => {:actions => [], :switches => []}
      @command_data = {}
      @top_level_commands = []
      @global_switches = []
      Commander::Runner.instance.options.each { |o| @global_switches << o[:switches][-1] }
    end

    def gen()
      process_data
      gen_script
    end

    private
      def cli_init
        runner = RHC::CommandRunner.new([])
        Commander::Runner.instance_variable_set :@singleton, runner
        RHC::Commands.load.to_commander
      end

      def process_data
        Commander::Runner.instance.commands.each_pair do |name, cmd|
          next if cmd.summary.nil?

          if name.rindex(' ').nil?
            @top_level_commands << name
          else
            commands = name.split ' '
            action = commands.pop
            id = commands.join(' ')
            data = @command_data[:"#{id}"] || {:actions => [],
                                               :switches => []}
            data[:actions] << action
            @command_data[:"#{id}"] = data
          end

          switches = []
          cmd.options { |o| switches << o[:switches][-1] if o[:switches] }
          data = @command_data[:"#{name}"] || {:actions => [],
                                               :switches => []}
          data[:switches] = switches.concat(@global_switches)
          @command_data[:"#{name}"] = data
        end
      end

      def gen_script
        @script_erb.result AutoCompleteBindings.new(@top_level_commands.join(' '), @command_data).get_binding
      end
  end
end
