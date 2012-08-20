module RHC::Commands
  class AutoComplete < Base
    argument :args, "list of commands", [], :arg_type => :list
    def run(args_list)
      autocomplete_list = []
      switch_list = []

      # remove comparing switches for now though we may wish to add some sort of
      # contextual callback for switches later (e.g. rhc cartridge add cart -a
      # could list available apps)
      i = autocomplete_list.index { |arg| arg.start_with '-' }
      autocomplete_list = autocomplete_list[0, i] unless i.nil?
      only_switches = i.nil? ? false : true
      Commander::Runner.instance.commands.each_pair do |name, cmd|
        arg_match = args_list.join ' '
        if name.match "^#{arg_match}"
          arg = name[arg_match.length, name.length].lstrip
          autocomplete_list << arg if arg.length !=0 and arg.count(' ') == 0 and cmd.summary != nil and not only_switches
          # this is the current command so add switches also
          cmd.options { |o| puts o.inspect; switch_list << o[:switches][-1] if o[:switches] } if arg.length == 0
        end
      end

      say autocomplete_list.concat(switch_list).join ' '
      0
    end
  end
end
