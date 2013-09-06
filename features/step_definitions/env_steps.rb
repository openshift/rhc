include RHCHelper

When /^'rhc env (\S+)( .*?)?'(?: command)? is run$/ do |subcommand, rest|
  if subcommand =~ /^(list|show|set|unset)$/
    Env.send subcommand.to_sym, rest
    @env_output = Env.env_output
    @exitcode = Env.exitcode
  end
end

When /^a new environment variable "(.*?)" is set as "(.*)"$/ do |name, value|
  step "'rhc env set --env #{name}=#{value} --app #{@app.name}' is run"
end

When /^an existing environment variable with name "(.*?)" is unset$/ do |name|
  step "'rhc env unset --env #{name} --app #{@app.name}' is run"
end

Given "the existing environment variables are listed" do
  step "'rhc env list --app #{@app.name}' is run"
end

Then /^the output environment variables (do not )?include "(.*)"$/ do |exclude, str|
  if exclude
    @env_output.should_not match(str)
  else
    @env_output.should match(str)
  end
end
