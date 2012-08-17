module RHC::Commands
  class AutoComplete < Base
    argument :args, "list of commands", [], :arg_type => :list
    def run(args_list)
      autocomplete_list = []
      Commander::Runner.instance.commands.each_pair do |name, opts|
        arg_match = args_list.join ' '
        if name.match "^#{arg_match}"
          arg = name[arg_match.length, name.length].lstrip
          autocomplete_list << arg if arg.length !=0 and arg.count(' ') == 0
        end
      end

      say autocomplete_list.join ' '
      0
    end
  end
end
