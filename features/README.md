Overview
==============

These tests can be run against a production or OpenShift Origin instance for
verification of basic functionality.  These tests should be operating system
independent and will shell out to execute the 'rhc *' commands to emulate a
user as closely as possible.  These tests exercise both the commandline
client and the underlying infrastructure and serve as integration level
verification tests for the entire stack.

Usage
=============

Run from the base directory with 

   <env variables> bundle exec rake features

'features' requires RHC_USERNAME+RHC_PASSWORD+RHC_NAMESPACE or
RHC_ENDPOINT to be set in the environment.

Using a proxy
--------------

You can use a proxy by setting the http_proxy environment variable.  For example

    http_proxy='http://proxyserver:proxyport/' bundle exec rake features

Bypassing SSH Key Validation
----------------------------
Because the user will be SSHing into an unknown host, we need to bypass
host key validation.
To do this, simply add the following environment variable before any
other commands (modify the path as needed):

  GIT_SSH=features/support/ssh.sh

Pre-defined users
-----------------

In many cases, these tests will be run with an existing, pre-created user.  The
tests should keep the resource needs of that user to a minimum, but in some
cases, the user might need to have an increased number of gears added to
support certain tests.

You use environment variables to notify the tests of the well defined user,
password and namespace.  This can be done by passing the values in before the
command:

    RHC_USERNAME='mylogin@example.com' RHC_PASSWORD='supersecretpassword' RHC_NAMESPACE='mynamespace' bundle exec rake features

Development Usage
=================

In development, you probably aren't going to be running against production systems.
You will most likely be running against your own OpenShift Origin system.  To be
able to point to a custom system, you can configure the REST endpoint that is used.
If not specified, it will default to the OpenShift Production REST Endpoint:

    RHC_ENDPOINT='https://myserver/rest/api' bundle exec rake features


Developing tests
----------------

Often when you are developing new tests, you don't want to run the entire suite
each time.  However, the tests by default automatically clean up the test
applications that were created on the previous run.  You can quickly develop
and interate on a single test by doing the following:

* Run the initialization portion of the test suite

    RHC_ENDPOINT='https://yourserver/rest/api' bundle exec cucumber -t @init

* Run the tests on your specific feature without reset state and using the
created username and namespace from the previous run. For example, if the
cucumber feature you wanted to test started on line 17, in your .feature file,
you would run

    RHC_USERNAME=`cat /tmp/rhc/username` RHC_NAMESPACE=`cat /tmp/rhc/namespace` RHC_ENDPOINT='https://yourserver/rest/api' NO_CLEAN=1 bundle exec cucumber features/verify.feature:20
