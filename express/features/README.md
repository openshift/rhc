Overview
==============

These tests can be run against a production or OpenShift Origin instance for
verification of basic functionality.  These tests should be operating system
independent and will shell out to execute the 'rhc *' commands to emulate a
user as closely as possible.

Pre-conditions
--------------

Primarily, these tests will be run with an existing, pre-created user.  The
tests should keep the resource needs of that user to a minimum, but in some
cases, the user might need to have an increased number of gears added to
support certain tests.

You use environment variables to notify the tests of the well defined user,
password and namespace.  This can be done by putting a block like the following
in your ~/.bashrc file:

    export RHC_USERNAME='mylogin@example.com'
    export RHC_PASSWORD='supersecretpassword'
    export RHC_NAMESPACE='mynamespace'

The REST API endpoint is also configurable and will default to the OpenShift production systems.  You can configure and alternative endpoint with

    export RHC_ENDPOINT='https://myserver/rest/api'

Warnings
--------

You might see warnings about some constants being loaded twice.  This is due to
the autoloading of cucumber in addition to the structured require ordering of
the rhc helpers.  You can avoid this by running cucumber with explicit requires.
For example, from within the express directory, you could run:

    cucumber --require features/support --require features/step_definitions
