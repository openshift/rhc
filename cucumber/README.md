DEPRECATED
=========
Cucumber is being phased out - please add RSpec style features to the features/* directory

Overview
==============

These tests can be run against a production or OpenShift Origin instance for
verification of basic functionality.  These tests should be operating system
independent and will shell out to execute the `rhc *` commands to emulate a
user as closely as possible.  These tests exercise both the command-line
client and the underlying infrastructure and serve as integration level
verification tests for the entire stack.

Usage
=============

Run from the base directory with

```
<env variables> bundle exec rake cucumber
```

At the very least, you will probably want to specify `RHC_SERVER` (or
the tests will run against the production OpenShift server by default).

You may also want to specify credentials to use a specific account on
the OpenShift server.

All of these environment variables are described in detail in [the
next section](#environment-variables).

If you are developing tests, or want to run specific tests, make sure to
check out the [development usage section](#development-usage).

Environment Variables
=====================
Much of the configuration for these tests is controlled through
environment variables.
They can be used with either the `rake` commands or when executing
`cucumber` directly.

http_proxy
----------
Since the `rhc` tools use a HTTP based REST API, if you need a proxy to
access the server you are testing against, you will need to specify a
proxy. For instance:

    http_proxy='http://proxyserver:proxyport/'

GIT_SSH
-------
This is automatically set in `cucumber/support/env.rb` but can be
overridden if desired.

This environment variable will be used by any `git` or `ssh` commands.
Currently, we are using it to bypass host key validation because the
user will be connecting to unknown hosts (the new OpenShift apps).
Without this variable, the tests will wait for approval before
connecting to the host.

RHC_DEV
-------
If set, this will use the `libra_server` specified in
`~/.openshift/express.conf` for `RHC_SERVER` (unless `RHC_SERVER` is
also specified).

RHC_(SERVER|ENDPOINT)
---------------------
This is the server/endpoint the tests will execute against.

If `RHC_SERVER` is set, it will set `RHC_ENDPOINT` to be
`https://#{RHC_SERVER}/broker/rest/api`.

If you need to point to another API endpoint, you can also specify the full
`RHC_ENDPOINT`.

If not set, these will default to the production OpenShift server.

RHC_(USERNAME|PASSWORD|NAMESPACE)
-----------------
In many cases, these tests will be run with an existing, pre-created user.  The
tests should keep the resource needs of that user to a minimum, but in some
cases, the user might need to have an increased number of gears added to
support certain tests.

These variables allow the tests to be run with the defined credentials
instead of randomly generating new ones.

NO_CLEAN
--------
This option prevents the tests from deleting the existing apps in this
namespace before running the tests.
It also prevents the tests from replacing the existing
`~/.openshift/express.conf`.

If this is specified, the script will use values stored in `/tmp/rhc/(username|namespace)` (unless overridden by `RHC_(USERNAME|NAMESPACE)`).

Development Usage
=================
When developing new features, whether for the `rhc` tools or OpenShift
server, these tests will help to ensure the tools continue to function
properly.

Running Tests
-------------
First, and foremost, you will want be able to run the tests.
Often when you are developing new tests, you don't want to run the entire suite
each time.
There are two ways to run them.

1. The `rake` command may add additional functionality, such as coverage
reporting.
  To run the test, simply run

    ```
    <env variables> bundle exec rake cucumber
    ```

1. Running the tests directly via `cucumber` gives you some more
flexibility as to which tests to run. You can run `cucumber` using any of the techniques [shown
here](https://github.com/cucumber/cucumber/wiki/Running-Features).

    For instance:

    ```
    # This runs all scenarios with the @application tag that also do not
    #   have the @init tag
    cucumber cucumber -t @application -t ~@init
    # This runs the scenario starting at a specific line in the file
    cucumber cucumber/application.feature:42
    ```

Developing tests
----------------

Due to their nature, some tests require previous state to
function properly.
For instance, in order to test adding cartridges to an application, an
application must exist first.

When the tests are run in order, this state is reused.
We have also devised a technique using before_hooks and backgrounds to
ensure the environment is in the correct state.

When a feature is run, there is generally a scenario tagged `@init` which does some sort of initialization step (such as creating an
application).

Normally, the other scenarios in the same feature will depend on this step to function
properly.
However, there are before_hooks defined for any `~@init` steps that
ensure that state is in place.
This way, you can run any scenario and know that you will have the same
state as if the `@init` step was run.


### Example
In our feature file, we may have something like this:

```
@demo
Feature: Demonstrating Hooks

  @init
  Scenario: Setting Up Demo
    Given we are giving a demo
    Then the demo directory should exist

  Scenario: Running a Demo
    Then we should start the demo

  Scenario: Deleting a demo
    Then the demo should be deleted
```

Notice we don't have another `Given` statement in our second or third scenario.
We take care of that in our before hooks.
If we were to run either of those scenarios on their own, they would fail.
We fix this by defining a step that can set the expected state if it
doesn't exist.

```
Given "a demo directory exists or is created" do
  begin
    Given "the demo directory exists"
  rescue RSpec::Expectations::ExpectationNotMetError
    Then "create the demo directory"
  end
end
```

Now we can define a `before_hook` that runs our steps before any
scenarios that are not tagged `@init`.

```
Before('@demo','~@init') do
  Given "a demo directory exists or is created"
end
```

After following these steps, we can confidently run any of our scenarios
and know that they will be in the state they expect.
