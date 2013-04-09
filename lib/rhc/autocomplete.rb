module RHC
  class AutoComplete
    attr_reader :runner

    def initialize(runner=::Commander::Runner.instance, shell='bash')
      @runner, @shell = runner, shell
    end

    def to_s
      @s ||= template.result AutoCompleteBindings.new(self).get_binding
    end

    private

      def template
        @template ||= ERB.new(File.read(File.join(File.dirname(__FILE__), 'autocomplete_templates', "#{@shell}.erb")), nil, '-')
      end
  end

  class AutoCompleteBindings
    attr_reader :commands, :top_level_commands, :global_options

    def initialize(data)
      @commands = {}
      @top_level_commands = []

      data.runner.commands.each_pair do |name, cmd|
        next if cmd.summary.nil?
        next if cmd.deprecated(name)

        if cmd.root?
          if cmd.name == name
            @top_level_commands << name
          end
        else
          @top_level_commands << name if name == cmd.name
          commands = name.split ' '
          action = commands.pop
          id = commands.join(' ')
          v = @commands[id] || {:actions => [], :switches => []}
          v[:actions] << action unless id == '' && name != cmd.name
          @commands[id] = v
        end

        v = @commands[name.to_s] || {:actions => [], :switches => []}
        v[:switches].concat(cmd.options.map do |o| 
          if o[:switches] 
            s = o[:switches][-1].split(' ')[0]
            if m = /--\[no-\](.+)/.match(s)
              s = ["--#{m[1]}", "--no-#{m[1]}"]
            else
              s
            end
          end
        end.flatten.compact.sort)
        @commands[name.to_s] = v
      end
      @commands.delete('')
      @commands = @commands.to_a.sort{ |a,b| a[0] <=> b[0] }

      @top_level_commands.sort!

      @global_options = data.runner.options.map{ |o| o[:switches][-1].split(' ')[0] }.sort
    end
  end  
end
