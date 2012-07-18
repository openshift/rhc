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
    def self.global_option(*args)
      global_options << args
    end
    def self.to_commander(instance=Commander::Runner.instance)
      global_options.each{ |args, block| instance.global_option *args }
      commands.each_pair do |name, opts|
        instance.command name do |c|
          c.description = opts[:description]
          c.summary = opts[:summary]
          options_metadata = opts[:options_metadata]
          options_metadata.each { |o| c.option *o } unless options_metadata.nil?
          args_metadata = opts[:args_metadata] || []
          args_metadata.each do |arg_meta|
            arg_option_switches = arg_meta[:option_switches]
            arg_option_switches << arg_meta[:description]
            c.option(*arg_option_switches) unless arg_option_switches.nil?
          end
          c.when_called do |args, options|
            begin
              # check to see if an arg's option was set
              raise ArgumentError.new("Too many arguments") if args.length > args_metadata.length
              args_metadata.each_with_index do |arg_meta, i|
                o = arg_meta[:option_switches]
                raise ArgumentError.new("Missing #{arg[:name]} argument") if o.nil? and args.length <= i
                value = options.__hash__[arg[:name]]
                unless value.nil?
                  raise ArgumentError.new("#{arg[:name]} specified twice on the command line and as a #{o[0]} switch") unless args.length == i
                  # add the option as an argument
                  args << value
                end
              end

              # call command
              opts[:class].new(c, args, options).send(opts[:method], *args)
            rescue ArgumentError => e
              help = instance.help_formatter.render_command(c)
              say "Error: #{e.to_s}#{help}"
            end
          end
        end
      end
      self
    end

    protected
      def self.commands
        @commands ||= {}
      end
      def self.global_options
        @options ||= []
      end
  end
end
