# Adding a new command to the RHC program

In an effort to make rhc commands more consistent and easier to write we have adopted the Commander module as the basis for the command line tools going forward.  Among some of the benefits Commander brings to the table is the ability to generate help documentation, auto complete directives and option parsing directly from the code.  It also allows us to efficiently handle functional and coverage tests without having to merge results from a number of binaries.  Bellow is a tutorial on how to write commands in the new framework.

## Global Options

Global options are switches that are specified on the command line that are available to every command.  They are specified in the lib/rhc/helpers.rb file.  You specify a global option in a format similar to OptionParser.

    global_option ['-p', '--password password'], "Red Hat password"

The first parameter is a list of short and long switches.  The long switch specifies the name of the key in the @options hash.  In this example that would be *password*.  Actions can access the option directly from the @options hash but in many cases global options are processed before the action is invoked.  For instance the password option is added to the config module inside the config accessor in lib/rhc/commands/base.rb.

<!-- language: ruby -->
    def config
      @config ||= begin
        RHC::Config.set_opts_config(options.config) if options.config
        RHC::Config.password = options.password if options.password
        RHC::Config.opts_login = options.rhlogin if options.rhlogin
        RHC::Config
      end
    end

## Config

All commands should access the config module through the config helper method to ensure all configuration options are set correctly and the correct configuration is used.

## Resources

Every top level rhc command is considered a resource.  For instance `rhc app`, `rhc domain` and `rhc sshkey` all work on the `app`, `domain` and `sshkey` resources respectively.  These resources then have commands associated with them.  Each resource is represented by a `Commander::Command` class which inherits from the `RHC::Commands::Base` class.

<!-- language: ruby -->
    require 'rhc/commands/base'

    module RHC::Commands
      class Domain < Base

        summary "Manage your domain"
        syntax "<action>"
        def run
          # default to domain show
          show
        end
      end
    end

## Resource Descriptors

Resource descriptors describe the behavior of a resource.  Right now the only resource descriptor is `suppress_wizard`.  By default all commands will execute the default setup wizard if --noprompt is not specified on the command line and the user has not yet configured their system to connect to OpenShift.  Some commands conflict with the wizard (for example the rhc setup command which already runs the wizard) so we provide a way of supressing it from running when any of the actions in the resource are invoked.

<!-- language: ruby -->
    module RHC::Commands
      class Setup < Base
        suppress_wizard

        summary "Runs the setup wizard to configure your OpenShift account."
        def run
          ...
        end
      end
    end

## Default Action

In the above example you will notice a run method.  This is the default action that gets executed when `rhc domain` is run.  Every resource should export a run command even if all it does is print usage information.  In this case we are calling the show action by default which will be described in a later section.  All actions have descriptors like summary and syntax, but you will notice the default action's descriptors are a little generic.  This is because the default actions descriptors are used to describe the resource when help is displayed.

You may alternatively alias another action as the default action using the `default_action` class method.  This works the same as defining the run method and calling the aliased method directly.  Using default_action is prefered in these cases as it is more descriptive.

<!-- language: ruby -->
    class Domain < Base
      summary "Manage your domain"
      syntax "<action>"
      default_action :show

      summary "Show your configured domains"
      def show
        ...
      end
    end

## Actions

Actions are simply public methods that are called when specified after a resource.  For instance `rhc domain create` will call the create method on the domain resource class.  All public method automatically become an action.  All helper methods should be declared protected or private.

## Action Descriptors

Action descriptors attach useful metadata to actons.  This allows us to consolidate information about a command in one place and generate documentation, autocomplete and input handling code in one place.  A developer should be able to take one look at an action's descriptors and understand how to call that code on the command line.  Below are a list of the current descriptors.

### summary(string)

Provides a short summary to use when printing out usage information to the user.

    summary "This is a summary"

### description(string)

a more descriptive explenation of the action used when a user specifically requests help on that action (e.g. rhc domain show help).  Description is optional.  Summary is used when a description does not exist.

    description "When executing this action stuff will happen.  You should be aware of this stuff because it is important."

### syntax(string)

This may be generated from metadata in the future but for now we use this to document the arguments and switches that come after the action.  This is used when printing out usage information.

<!-- language: ruby -->
    class Domain < Base
      ...
      syntax "\<namespace\> [--timeout timeout]"
      def create(namespace)
        ...
      end
    end

Running `rhc domain create help` would print out **Usage: rhc domain create \<namespace\> [--timeout timeout]**

### option([switches], description)

This specifies an option that this action takes.  Switches are specified in option parser syntax.  You may specify a short and a long switch with the long switch defining the name of the option (e.g. ["-t", "--timeout timeout"]). The description is used in help generation.  You may specify more than one option if needed.

<!-- language: ruby -->
    class Domain < Base
      ...
      option ["-t", "--timeout timeout"], "Timeout, in seconds, for the session"
      def create(namespace)
        ...
      end
    end

Since the long switch is called --timeout, timeout will be the key used in the @options hash available to the action.  By specifying a string after the long switch we indicate that this option takes an input.  Long switches without the following sting are considered boolean and are set to *true* if it is passed on the command line.  Short switches are optional though encouraged.

### argument(name, description, [switches])

This specifies that the action takes an argument.  Arguments are strings passed on the command line that do not invoke an action.  For instance `rhc domain create mynamespace` will pass mynamespace as the namespace argument.  You must describe an argument in order to have it passed into an action otherwise an error will trigger and usage information will be printed out when the action is invoked.  The optional switches at the end of the argument are option switches which the user can use to specify the argument.  This is mostly to support legacy interfaces where parameters like namespace had to be specified via the --namespace switch.  Arguments are required to be specified either as a parameter or as a switch.  If they are specified both ways an error will occure.  As of this writting we do not support optional arguments.  If you require them please use an option.  If there are legitimate use cases we may be able to support optional arguments in the future.

<!-- language: ruby -->
    class Domain < Base
      ...
      argument :namespace, "Namespace for your application(s) (alphanumeric)", "-n", "--namespace namespace"
      def create(namespace)
        ...
      end
    end

## Return Codes and Exceptions

All actions should return a code of 0 if everything is run successfully.  For readablity we provide a command_success convinience method.  The method is simply an alias for 0 so if you return from the action anywhere other than the end you must use `return command_success`.

<!-- language: ruby -->
    def run
      ...
      command_success
    end

To specify an error you can simply return a non-0 number but if you raise an exception usage info is automatically printed to the console.  Right now we use `Rhc::Rest::BaseException` because it provides a way to specify the exact exit code but in the future we may specify a set of standard errors with standard error codes already set.

<!-- language: ruby -->
    def run
      ...
      # some error state is reached
      raise Rhc::Rest::BaseException.new("An error has occured", 127)
    end

## Placement of Resources

All resources should be placed in this (lib/rhc/commands) directory. The name of the file should be <resource_name>.rb and the class should be named accordingly.

## List of Important Command Files

* lib/rhc/cli.rb - entry point when rhc binary in invoked
* lib/rhc/commands.rb - place where metadata for commands are processed and the commands are setup and executed
* lib/rhc/helpers.rb - where we setup global options
* lib/rhc/commands/base.rb - base class for all resource objects for our commands

## Further Functionality Not Yet Implemented and Open For Discussion

### Nested Resources

Some resources are part of other resources. For example cartridge resources which live off of the App resource.  There needs to be a way to specify these and also make sure they do not show up as top level resources but otherwise act the same.

### Context Sensitive Actions

In the future we want to be able to automatically fill in some values gathered from the current git directory to save the user some typing.  For instance if I am in an application's git directory typing in `rhc cartridge add` should automatically call the cartridge resource and pass the app's id and the namespace to the action.  This should be able to be specified through metadata without creating a whole new command structure.
