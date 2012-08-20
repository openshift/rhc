require 'commander'

module RHC::Commands
  class AutoComplete
    def run(args)
      autocomplete_list = []
      switch_list = []

      # remove 'autocomplete' arg
      args.shift

      # remove comparing switches for now though we may wish to add some sort of
      # contextual callback for switches later (e.g. rhc cartridge add cart -a
      # could list available apps)
      i = args.index { |arg| arg.start_with? '-' } || args.length
      args = args[0, i]
      only_switches = (i < args.length) ? true : false
      Commander::Runner.instance.commands.each_pair do |name, cmd|
        arg_match = args.join ' '
        if name.match "^#{arg_match}"
          arg = name[arg_match.length, name.length].lstrip
          autocomplete_list << arg if arg.length !=0 and arg.count(' ') == 0 and cmd.summary != nil and not only_switches
          # this is the current command so add switches also
          cmd.options { |o| switch_list << o[:switches][-1] if o[:switches] } if arg.length == 0
        end
      end

      say autocomplete_list.concat(switch_list).join ' '
      0
    end
  end
end
