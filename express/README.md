# OpenShift Command Line Tools (RHC) [![Build Status](https://secure.travis-ci.org/openshift/os-client-tools.png)](http://travis-ci.org/openshift/os-client-tools)

The OpenShift command line tools allow you to manage your OpenShift
applications from the command line.  The [Getting Started
guide](https://openshift.redhat.com/app/getting_started) has additional
info on installing the tool on each supported operating system.

Please stop by #openshift on irc.freenode.net if you have any questions or
comments.  For more information about OpenShift, visit https://openshift.redhat.com
or the OpenShift forum
https://openshift.redhat.com/community/forums/openshift.


## Using RHC to create an application

DEPENDENCIES: 

* git
* openssh-clients
* ruby (1.8.7 or later)
* rubygems
* json_pure gem (native json is fine too)
* parseconfig gem

Step 1:  Create a domain to under which your applications will live:

    $ rhc domain create -n desirednamespace -l rhlogin

The name you choose here will form part of your application's public
URL.

Step 2: Create an OpenShift application:

    $ rhc app create -l rhlogin -a appname -r /path/to/new/git/repo -t <framework Ex: php-5.3>

Once that's complete, follow the directions printed at the end of running
rhc app create


## Making changes to your application

Once your site is created, updating it is as simple as making changes to your
git repo.  Commit them, then push.  For example:

    $ edit index.php
    $ git commit -a -m "what I did"
    $ git push

Then just reload your web page to see the changes.

## OS X Notes:

git:
OS X 10.6 comes w/ ssh and ruby, but not with git, unless you have
Xcode 4.0.x installed (as a developer you should have Xcode anyway).
Xcode, however, is not free (unless you are a registered Apple
Developer) and costs around $5 from the Apple App Store.

If you do not have Xcode, you can obtain a pre-packaged version
of git from:

    http://code.google.com/p/git-osx-installer/

Installing git from MacPorts/HomeBrew/Fink/etc requires Xcode.

Now obtain the client code, either via 'git clone' as above
or via the rhc gem.

json_pure gem:
The client tools also make use of JSON as the data set for
I/O, and therefore needs the json ruby gem. Unless you have
Xcode installed, you will need to install json_pure, which
is the 100% ruby version of the JSON gem. If you have Xcode,
you can elect to install either json_pure or the native
json gem.
