require 'rhc/commands/base'

module RHC::Commands
  class Env < Base
    summary "Manages user-defined environment variables set on a given application"
    syntax "<action>"
    description <<-DESC
      Manages the user-defined environment variables set on a given
      application. To see a list of all environment variables use the command
      'rhc list-env <application>'. Note that some predefined
      cartridge-level environment variables can also be overriden,
      but most variables provided by gears are read-only.

      Type 'rhc set-env --help' for more details.

      DESC
    default_action :help
    alias_action :"app env", :root_command => true

    summary "Set one or more environment variable(s) to your application"
    description <<-DESC
      Set one or more environment variable(s) to your application.
      Operands of the form 'VARIABLE=VALUE' set the environment
      variable VARIABLE to value VALUE. Example:

      rhc set-env VARIABLE1=VALUE1 VARIABLE2=VALUE2 -a myapp

      Environment variables can also be set from a file containing one
      or more VARIABLE=VALUE pairs (one per line). Example:

      rhc set-env /path/to/file -a myapp

      VALUE may be empty, in that case 'VARIABLE='. Setting a
      variable to an empty value is different from unsetting it.

      Some default cartridge-level variables can be overriden, but
      variables provided by gears are read-only.

      DESC
    syntax "<VARIABLE=VALUE> [... <VARIABLE=VALUE>] [--namespace NAME] [--app NAME]"
    argument :env, "Environment variable name and value pair separated by an equal (=) sign, e.g. VARIABLE=VALUE", ["-e", "--env VARIABLE=VALUE"], :optional => false, :arg_type => :list
    option ["-a", "--app NAME"], "Application name (required)", :context => :app_context, :required => true
    option ["-n", "--namespace NAME"], "Namespace of your application", :context => :namespace_context, :required => true
    option ["--confirm"], "Pass to confirm setting the environment variable(s)"
    alias_action :add
    def set(env)
      rest_app = rest_client.find_application(options.namespace, options.app)

      with_file = env.index {|item| File.file? item}

      env_vars = []
      env.each {|item| env_vars.concat(collect_env_vars(item))}
      raise RHC::EnvironmentVariableNotProvidedException.new(
        (with_file ?
          "Environment variable(s) not found in the provided file(s).\n" :
          "Environment variable(s) not provided.\n") <<
          "Please provide at least one environment variable using the syntax VARIABLE=VALUE.") if env_vars.empty?

      if with_file
        env_vars.each {|item| default_display_env_var(item.name, item.value)}
        confirm_action "Do you want to set these environment variables on '#{rest_app.name}?"
      end

      say 'Setting environment variable(s) ... '
      rest_app.set_environment_variables(env_vars)
      success 'done'

      0
    end

    summary "Remove one or more environment variable(s) currently set to your application"
    description <<-DESC
      Remove one or more environment variable(s) currently set to your
      application. Setting a variable to an empty value is
      different from unsetting it. When unsetting a default cartridge-
      level variable previously overriden, the variable will be set
      back to its default value.

      DESC
    syntax "<VARIABLE> [... <VARIABLE>] [--namespace NAME] [--app NAME]"
    argument :env, "Name of the environment variable(s), e.g. VARIABLE", ["-e", "--env VARIABLE"], :optional => false, :arg_type => :list
    option ["-a", "--app NAME"], "Application name (required)", :context => :app_context, :required => true
    option ["-n", "--namespace NAME"], "Namespace of your application", :context => :namespace_context, :required => true
    option ["--confirm"], "Pass to confirm removing the environment variable"
    alias_action :remove
    def unset(env)
      rest_app = rest_client.find_application(options.namespace, options.app)

      warn 'Removing environment variables is a destructive operation that may result in loss of data.'

      env.each do |e|
        default_display_env_var(e)
      end

      confirm_action "Are you sure you wish to remove the environment variable(s) above from application '#{rest_app.name}'?"
      say 'Removing environment variable(s) ... '
      rest_app.unset_environment_variables(env)
      success 'removed'

      0
    end

    summary "List all environment variables set on the application"
    description <<-DESC
      List all user-defined environment variables set on the application.
      Gear-level variables overriden by the 'rhc set-env' command
      will also be listed.

      DESC
    syntax "<app> [--namespace NAME]"
    argument :app, "Application name (required)", ["-a", "--app name"], :context => :app_context, :required => true
    option ["-n", "--namespace NAME"], "Namespace of your application", :context => :namespace_context, :required => true
    option ["--table"], "Format the output list as a table"
    option ["--quotes"], "Format the output list with double quotes for env var values"
    def list(app)
      rest_app = rest_client.find_application(options.namespace, app)
      rest_env_vars = rest_app.environment_variables

      pager

      display_env_var_list(rest_env_vars, { :table => options.table, :quotes => options.quotes })

      0
    end

    summary "Show the value of one or more environment variable(s) currently set to your application"
    syntax "<VARIABLE> [... <VARIABLE>] [--namespace NAME] [--app NAME]"
    argument :env, "Name of the environment variable(s), e.g. VARIABLE", ["-e", "--env VARIABLE"], :optional => false, :arg_type => :list
    option ["-a", "--app NAME"], "Application name (required)", :context => :app_context, :required => true
    option ["-n", "--namespace NAME"], "Namespace of your application", :context => :namespace_context, :required => true
    option ["--table"], "Format the output list as a table"
    option ["--quotes"], "Format the output list with double quotes for env var values"
    def show(env)
      rest_app = rest_client.find_application(options.namespace, options.app)
      rest_env_vars = rest_app.find_environment_variables(env)

      pager

      display_env_var_list(rest_env_vars, { :table => options.table, :quotes => options.quotes })

      0
    end

  end

end
