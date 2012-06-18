Overview
==============

These tests can be run against a production or OpenShift Origin instance for
verification of basic functionality.  These tests should be operating system
independent and will shell out to execute the 'rhc *' commands to emulate a
user as closely as possible.

Dependencies
--------------

These tests require the following gems installed

* commander
* rspec
* benchmark
* dnsruby
* open4
* activesupport

You can install these with:

    sudo gem install commander rspec benchmark dnsruby open4 activesupport

Pre-conditions
--------------

Primarily, these tests will be run with an existing, pre-created user.  The
tests should keep the resource needs of that user to a minimum, but in some
cases, the user might need to have an increased number of gears added to
support certain tests.

You use environment variables to notify the tests of the well defined user,
password and namespace.  This can be done by putting a block like the following
in your ~/.bashrc file:

    export RHC_RHLOGIN='mylogin@example.com'
    export RHC_PWD='supersecretpassword'
    export RHC_NAMESPACE='mynamespace'

If you do not supply this information, the tests will assume you have setup an
unauthenticated environment and will try and create unique domains and
application using a pre-canned password.

Post-conditions
--------------

It is also your responsibility to clean up after the tests have run.  Currently,
the tests keep all operations on a single application called 'test'.  If you are
using the environment variables to export the RHC information, a handy one line
cleanup script is provided at:

    features/cleanup.rb

Warnings
--------

You might see warnings about some constants being loaded twice.  This is due to
the autoloading of cucumber in addition to the structured require ordering of
the rhc helpers.  You can avoid this by running cucumber with explicit requires.
For example, from within the express directory, you could run:

    cucumber --require features/support --require features/step_definitions
