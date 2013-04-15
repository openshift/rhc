# Abstract

This document goes over the architecture of the commander based RHC tool. This is a developers document for those who need to modify the internals as opposed to just adding a new command. For documentation adding commands please refer to the ADDING_COMMANDS.md file.

In this document we will go over the several layers of rhc describing its function and design decisions we made. Where we change the functionality of the underlying commander module we will go over why we decided to diverge from the standard implementation.

# The General Flow

Commands are defined in the lib/rhc/commands directory. These commands export metadata from their class name, public methods and decorator methods which all get loaded when the rhc binary is executed. This metadata describes how each command is called, what documentation they have and what options, if any, are available to send to the command.

When the rhc binary is executed it loads the CLI entry point in lib/rhc/cli.rb. This is a simple setup class which creates the Commander runner (the class that runs the command) and loads all of the commands into that runner. The runner itself sets up the global options and figures out which command class to instantiate and run based on the arguments passed into the rhc binary.

The runner also handles any errors that happen during the execution of the command. This allows us to throw errors in the commands which are handled gracefully for the user eliminating multiple error handling paths. If a traceback happens without --trace being passed in this is usually due to an actual error in the code and not a user error.

Once a command is identified and it is prepared to run. This is when options are parsed based on the global and local option metadata. All options are passed to the command object on creation but some of the global options are defined with blocks that are executed if the option is specified on the command line.

After creating the command object the runner will process the arguments based on the metadata specified for the method to be called to handle the command. If there are any errors in the specified options or arguments this is when exceptions will be raised before even executing the command. This is done so the commands themselves do not have each provide the code to validate the correct number of arguments are passed in. This also allows higher level functionality like filling in context arguments based on git config data. By relying on metadata instead of handing argument processing in each command we provide a consistent way to define command interfaces and allow command implementors to concentrate on the command code itself.

Once the arguments are processed and no exceptions are raised due to bad input the control is passed to the appropriate command method with arguments being passed in as normal parameters. It is here command implementors will write their code to handle this particular command utilizing the rest models to talk to the OpenShift servers. If any exception is thrown here, rhc will exit with an error code with the exception's message shown to the user. If the hidden global option --trace is passed in we bypass the error handling code and let the whole stacktrace be displayed for debugging purposes. If no exception is thrown whatever integer is returned from the command method will become the exit code. In all cases except a few this should be 0 to signify success.

# The Layers

Each layer handles the flow of execution to produce a consistent command line interface to the RHC commands. It is important while working with the internals to make changes at the right layer. The objective is to have a consistent way of writing commands that hides most of the complexities from the command implementor. Below is a diagram of the layers we will be talking about.

        rhc executable
            |
          CLI entry point
              |
            Command Loading -> metadata protocol
                |
             Command Runner
                  |
                Option Parser
                    |
                  Argument Processor ->
                      |     argument options -> context options
                      |
                    Command Execution
                        |
                      Exit Handling

## rhc executable

This is simply the executable that gets installed into the bin directory.  All it does is call the CLI layer and gracefully handle system exits and interrupts such as the user hitting ctrl-c. It should be noted that all interrupts are treated as errors so if a command like `rhc tail` require the user to hit ctrl-c to exit, the command itself should catch the interrupt and exit normally.

## CLI Entry Point

This is implemented in the `RHC::CLI` module in the `lib/rhc/cli.rb` file. This is the entry point for rhc and the setup point for the commander module that controls the who process.

The set_terminal method is first called by rhc to setup output options such as line wrapping and color coding. On Windows we turn off color coding because it requires the user setup ANSI terminal emulation, without which the ansi control codes show up as garbage on the screen. Windows has its own terminal formatting API which is not yet supported by the `highline` module we and commander use for output.

The start method is the heart of the cli. This method creates the commander runner, sets up metadata such as version, application name, and the help formatter, and then runs the runner.

## Command Loading

The Command Loading layer is controlled in the `RHC::Commands` module inside of the `lib/rhc/commands.rb` source file. Some of the details of the loading happen inside the base class for the commands themselves which reside in the `lib/rhc/commands/base.rb` source file.

The load method is first called by the cli to dynamically import all the ruby files inside of the `lib/rhc/commands/` directory. All of the magic for registering commands happens in the base class inside of the `method_added` method. This is a standard ruby class method which gets triggered when the class gets parsed by the ruby runtime and a method is parsed and added to it. We first make sure the method does not come from the base class and is public. It is here where the command is initially registered as a set of metadata based on the method name and class name. So for instance, a `Cartridge` class with a public `add` method would register metadata for an `rhc cartridge add` command.  We will get to the metadata in more depth later on in this section.

After the load method is called and all the command metadata is registered the to_commander method is called. It is here where the actual commands are setup to be executed based on their metadata. The metadata is looped over and the commands objects are instantiated.  Here we:

 * give the command its name, summary and description
 * setup any options with the command's option parser
 * setup options which are attached to arguments
 * setup the deprecation lists
 * setup any aliases
 * setup the block that will be called during execution to handle parsing the arguments and running the command

It should be noted that commander's command which is being setup above is separate from the command implementation classes in `lib/rhc/commands/`. The implementation is called by the executable block and provides metadata while the concept of the commander's command wraps the implementation so that the commander module has a standard interface to execute the implementation. The other reason for the split is for the help and documentation modules which aren't going to run the implementation. They simply need the wrapper (plus our own layer of metadata) to output documentation.

### metadata protocol

Commands are setup via metadata which is placed in a hash by class methods during class import and then associated with a command via the `method_added` mechanism described above. This is one of the most important sub layers as it is how we are able to describe commands in a consistent manner that gets the implementation complexities away from the command implementors. Take for instance this code:

        summary "Add a cartridge to your application"
        syntax "<cartridge_type> [--namespace NAME] [--app NAME]"
        option ["-n", "--namespace NAME"], "Namespace of the application you are adding the cartridge to", :context => :namespace_context, :required => true
        option ["-a", "--app NAME"], "Application you are adding the cartridge to", :context => :app_context, :required => true
        argument :cart_type, "The type of the cartridge you are adding (run 'rhc cartridge list' to obtain a list of available cartridges)", ["-c", "--cartridge cart_type"]
        alias_action :"app cartridge add", :root_command => true, :deprecated => true
        def add(cart_type)
          .
          .
          .
        end

This may look like a bunch of descriptors for the add method, and conceptually that is exactly what they are. They describe the documentation, what options are available, what arguments are required and what aliases should be created. They are however implemented as protocol with a set of class methods (e.g. summary) which add keys to a metadata hash which is then associated with the add command once it is parsed. When the add command is parsed and `method_added` is called the metadata is placed in another hash with the command name as its key and the metadata hash is cleared so the next command can start to fill it up with its own descriptors.

In this way we can add more descriptor methods and simply add new keys to the hash that will be used by the loader and runner for added functionality. For instance I could add an `example` descriptor for documenting how to use a command which could be used later by a tool that outputs man pages. The tool would have to simply request the metadata for the command and look up the `examples` key or something similar.

# Command Runner

This is the heart of commander where the command is selected based on input and run. Here we override the `run!` method of commander's runner class. We do because we made design decisions on how we parse options and arguments.  We also handle exceptions slightly differently than the stock runner.

## OptionParser

One of the changes we made was the parsing of global options. Commander requires a couple of global options to be parsed before running the command so it parses and removes them before parsing the local command options. This includes handling of the --trace and --version options. Because of design decisions in the base OptionParser module, this causes issues. For example OptionParser assumes if you have defined a --trace option but have not a -t short option that it will map -t to --trace. Since the local options are parsed separately there is a chance that the global options will parse the same value causing side effects.

To combat this while still allowing some options to be parsed early we simply edge case the early options and parse the rest of the global options along with the local ones when running the command.

Since the early options we parse are booleans we forgo using OptionParser and simply search the argv array for them. If found the boolean is set to true and the argument is removed from the array.

To parse the rest of the options we override the `Commander::Command.parse_options_and_call_procs` method, adding the global options to the parser. When an option is parsed it sets a hash which is passed into the command implementation on initialization. Some options also have blocks associated with them which are executed when the option is parsed.

## Argument Processor

Before a command is called we process the arguments in `RHC::Command::Base.validate_args_and_options` to do some basic validation and to do some advanced processing such as context options, mapping argument options to their respective argument and handling deprecated options. This is where you would add processing for new features such as context arguments.

### Argument Options

Arguments may have associated options defined giving the user the ability to specify the argument via a positional argument or an option switch. When processing an argument which has options mapped to it we simply look to see if the options hash contains a value. If it does, the slot for that option is filled in with the hash's value.  Otherwise we fill the slot from the arguments passed in.

### Context Options

Context options are options we fill in via a method. If the option is not set the set context method is called and the return value gets set in the options hash.  We add context methods to the `lib/rhc/context_helper.rb` source file and include the helpers in the base commands class in order to make them available to all commands. As of now the two context options are namespace and application. For namespace we simply return the first domain namespace available since we do not support multiple domains yet.  This can to be updated in the future to use the app uuid. For applications we look into the git config to look for the rhc.app-uuid key. If available we use that to look up the application name to pass for the context.

## Command Execution

After the positional arguments are set we first check to see if we need to run the setup wizard to configure the user to execute a command successfully. We then pass the arguments to the method mapped to the current command. At this point the command implementation takes over and uses all the information in the options hash and from the arguments to complete its task.

To avoid complexity the implementation for the most part should not rescue an exceptions. If an exception happens it will be handled in the exit handling layer.  Implementations must return an integer representing the exit code (0 for success) or raise an exception if it wishes to exit with an error.

## Exit Handling

Exits are handled two different ways depending if --trace is passed in. If --trace is passed in we run the command without any exception handling.  If an error occurs with trace set, ruby will print out a stacktrace. This is used for debugging purposes.

If trace is not set we catch a number of exceptions and display help or not based on the exception type.  Note that we don't handle all exceptions. The theory here is that programmer mistakes should always stacktrace but exceptions we know will mostly be raised from user input error are caught and handled.
