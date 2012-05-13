module RHC
  module Commands 
    def self.load
      Dir[File.join(File.dirname(__FILE__), "commands", "*.rb")].each do |file|
        require file
      end
      self
    end   
    def self.add(opts)
      commands[opts[:name]] = opts
    end
    def self.to_commander(instance=Commander::Runner.instance)
      commands.each_pair do |name, opts|
        instance.command name do |c|
          c.when_called do |args, options|
            opts[:class].new(args, options).send(opts[:method])
          end
        end
      end
      self
    end

    protected
      def self.commands
        @commands ||= {}
      end
  end
end
