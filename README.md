# OpenShift Command Line Tools (RHC) [![Build Status](https://secure.travis-ci.org/openshift/rhc.png)](http://travis-ci.org/openshift/rhc)

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

Step 1:  Run the setup command to configure your system:

    $ rhc setup

Follow the instructions in setup to set your SSH keys and create a domain.  The name you choose for your domain will form part of your application's public URL.

Step 2: Create an OpenShift application:

    $ rhc app create -a appname -r /path/to/new/git/repo -t <framework Ex: php-5.3>

Once that's complete, follow the directions printed at the end of running
rhc app create.


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


## Developing / Contributing
We expect code contributions to follow these standards:

1. Ensure code matches the [GitHub Ruby styleguide](https://github.com/styleguide/ruby), except where the file establishes a different standard.
2. We use RSpec for functional testing and Cucumber for our high level
   integration tests.  Specs are in 'spec/' and can be run with <code>bundle
exec rake spec</code>.  Features are in 'features/' and can be run with
<code>bundle exec rake features</code> (although these tests runs
against the gem installed locally so you will need to gem install
first).  See [README.md](https://github.com/openshift/rhc/blob/master/features/README.md) in the features dir for more info.
3. We maintain 100% line coverage of all newly added code via spec
   testing.  The build will fail if new code is added and it does not
have full line coverage.  Some old code is currently excluded until it
can be refactored.  Run <code>bundle exec rake spec</code> on Ruby 1.9+
to see your code coverage level.

Once you've made your changes:

1. [Fork](http://help.github.com/forking/) the code
2. Create a topic branch - `git checkout -b my_branch`
3. Push to your branch - `git push origin my_branch`
4. Create a [Pull Request](http://help.github.com/pull-requests/) from your branch
5. That's it!

If you use vim, we've included a .vimrc in the root of this project.
In order to use it, install https://github.com/MarcWeber/vim-addon-local-vimrc

