%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)

Summary:       Multi-tenant cloud management system client tools
Name:          rhc
Version:       0.85.2
Release:       1%{?dist}
Group:         Network/Daemons
License:       MIT
URL:           http://openshift.redhat.com
Source0:       rhc-%{version}.tar.gz

BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildRequires: rubygem-rake
BuildRequires: rubygem-rspec
Requires:      ruby >= 1.8.5
Requires:      rubygem-parseconfig

%if 0%{?fedora} == 13
%define jpure 1
%endif
%ifos darwin
%define jpure 1
%endif

%if 0%{?jpure} == 1
Requires:      rubygem-json_pure
%else
Requires:      rubygem-json
%endif
Requires:      git

BuildArch:     noarch

%description
Provides OpenShift client libraries

%prep
%setup -q

%build
for f in bin/rhc*
do
  ruby -c $f
done

for f in lib/*.rb
do
  ruby -c $f
done

%install
pwd
rm -rf $RPM_BUILD_ROOT

mkdir -p "$RPM_BUILD_ROOT/usr/share/man/man1/"
mkdir -p "$RPM_BUILD_ROOT/usr/share/man/man5/"

for f in man/*
do
  len=`expr length $f`
  manSection=`expr substr $f $len $len`
  cp $f "$RPM_BUILD_ROOT/usr/share/man/man${manSection}/"
done

mkdir -p $RPM_BUILD_ROOT/etc/openshift
if [ ! -f "$RPM_BUILD_ROOT/etc/openshift/express.conf" ]
then
  cp "conf/express.conf" $RPM_BUILD_ROOT/etc/openshift/
fi

# Package the gem
rake --trace package

mkdir -p .%{gemdir}
gem install --install-dir $RPM_BUILD_ROOT/%{gemdir} --bindir $RPM_BUILD_ROOT/%{_bindir} --local -V --force --rdoc \
     pkg/rhc-%{version}.gem

# Copy the bash autocompletion script and source it
# Check if the bash completion directory is present
if [ -d /etc/bash_completion.d ]
then
  cp -f lib/rhc /etc/bash_completion.d/rhc
  . /etc/bash_completion.d/rhc
fi


%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc doc/USAGE.txt
%{_bindir}/rhc
%{_bindir}/rhc-app
%{_bindir}/rhc-domain
%{_bindir}/rhc-sshkey
%{_bindir}/rhc-chk
%{_bindir}/rhc-create-app
%{_bindir}/rhc-create-domain
%{_bindir}/rhc-ctl-domain
%{_bindir}/rhc-domain-info
%{_bindir}/rhc-user-info
%{_bindir}/rhc-ctl-app
%{_bindir}/rhc-snapshot
%{_bindir}/rhc-tail-files
%{_bindir}/rhc-port-forward
%{_mandir}/man1/rhc-*
%{_mandir}/man5/express*
%{gemdir}/gems/rhc-%{version}/
%{gemdir}/cache/rhc-%{version}.gem
%{gemdir}/doc/rhc-%{version}
%{gemdir}/specifications/rhc-%{version}.gemspec
%config(noreplace) %{_sysconfdir}/openshift/express.conf

%changelog
* Tue Jan 17 2012 Dan McPherson <dmcphers@redhat.com> 0.85.2-1
- use rhc-domain-info consistently (dmcphers@redhat.com)
- fix for bug 773144 (abhgupta@redhat.com)

* Fri Jan 13 2012 Dan McPherson <dmcphers@redhat.com> 0.85.1-1
- bump spec numbers (dmcphers@redhat.com)

* Fri Jan 13 2012 Dan McPherson <dmcphers@redhat.com> 0.84.13-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- accounting for change to the response structure for ssh keys
  (abhgupta@redhat.com)

* Thu Jan 12 2012 Dan McPherson <dmcphers@redhat.com> 0.84.12-1
- Bump expected API version to 1.1.2 (key_type required on rhc-create-domain)
  (aboone@redhat.com)

* Wed Jan 11 2012 Dan McPherson <dmcphers@redhat.com> 0.84.11-1
- man page updates (dmcphers@redhat.com)
- man page updates (dmcphers@redhat.com)

* Wed Jan 11 2012 Dan McPherson <dmcphers@redhat.com> 0.84.10-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- adding man files for the newly added CLI commands (abhgupta@redhat.com)
- Remove output about threaddump command, this is handled by the cartridges now
  (aboone@redhat.com)
- Added test-unit dependency for Ruby 1.9 (fotios@redhat.com)

* Tue Jan 10 2012 Dan McPherson <dmcphers@redhat.com> 0.84.9-1
- adding more clarity to the help description for rhc-ctl-domain -a based on
  discussion with docs (abhgupta@redhat.com)
- displaying SSH key type in rhc-domain-info (abhgupta@redhat.com)
- placing validations after checking if --help is requested
  (abhgupta@redhat.com)

* Mon Jan 09 2012 Dan McPherson <dmcphers@redhat.com> 0.84.8-1
- Changing the deprecation warning for rhc-user-info (abhgupta@redhat.com)
- moving comments to debug mode (abhgupta@redhat.com)
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- fixing typo in the script help/usage description (abhgupta@redhat.com)

* Mon Jan 09 2012 Dan McPherson <dmcphers@redhat.com> 0.84.7-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- reflecting changes in rhc spec file (abhgupta@redhat.com)

* Fri Jan 06 2012 Dan McPherson <dmcphers@redhat.com> 0.84.6-1
- adding output comment to highlight command for user ssh key management
  (abhgupta@redhat.com)
- reverting a change that was made for local testing (abhgupta@redhat.com)
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- ensuring rhc-chk does not fail if issued from a machine using a non-default
  ssh key (abhgupta@redhat.com)

* Fri Jan 06 2012 Dan McPherson <dmcphers@redhat.com> 0.84.5-1
- specifying the ssh key type in the request to the controller
  (abhgupta@redhat.com)
- adding features for namespace deletion and user ssh key (additional keys)
  management (abhgupta@redhat.com)

* Tue Jan 03 2012 Dan McPherson <dmcphers@redhat.com> 0.84.4-1
- better formatting (dmcphers@redhat.com)

* Fri Dec 16 2011 Dan McPherson <dmcphers@redhat.com> 0.84.3-1
- update man page for threaddump (bdecoste@gmail.com)

* Thu Dec 15 2011 Dan McPherson <dmcphers@redhat.com> 0.84.2-1
- use actual app name in note (wdecoste@localhost.localdomain)

* Wed Dec 14 2011 Dan McPherson <dmcphers@redhat.com> 0.84.1-1
- bump spec number (dmcphers@redhat.com)

* Tue Dec 13 2011 Dan McPherson <dmcphers@redhat.com> 0.83.7-1
- added threaddump script doc (wdecoste@localhost.localdomain)
- remove extra message (dmcphers@redhat.com)
- Merge branch 'master' of github.com:openshift/os-client-tools
  (ffranz@redhat.com)
- Updated man pages (ffranz@redhat.com)

* Mon Dec 12 2011 Dan McPherson <dmcphers@redhat.com> 0.83.6-1
- Now using popen3(ssh) for rhc-port-forward instead of Net::SSH - we don't
  want to require additional gems (ffranz@redhat.com)
- US1550: add threaddump command (wdecoste@localhost.localdomain)

* Sun Dec 11 2011 Dan McPherson <dmcphers@redhat.com> 0.83.5-1
- New client tool rhc-port-forward for SSH tunelling (ffranz@redhat.com)

* Wed Dec 07 2011 Matt Hicks <mhicks@redhat.com> 0.83.4-1
- Check for inconsistent client/server API versions, warn user
  (aboone@redhat.com)

* Tue Dec 06 2011 Alex Boone <aboone@redhat.com> 0.83.3-1
- 

* Tue Dec 06 2011 Alex Boone <aboone@redhat.com> 0.83.2-1
- Construct the Git url earlier in case we have to include it in an error
  message (aboone@redhat.com)

* Thu Dec 01 2011 Dan McPherson <dmcphers@redhat.com> 0.83.1-1
- bump spec version (dmcphers@redhat.com)

* Wed Nov 30 2011 Dan McPherson <dmcphers@redhat.com> 0.82.18-1
- Bugzilla ticket 710112 Fix up http_proxy environment variable to allow
  username and password.  Also allow it to specify a full URL for compat with
  other utilities.  All of these should now work:
  http://foo@bar:10.11.12.13:3128/ http://10.11.12.13:3128
  foo@bar:10.11.12.13:3128 10.11.12.13:3128 (rmillner@redhat.com)

* Mon Nov 28 2011 Dan McPherson <dmcphers@redhat.com> 0.82.17-1
- Added global config file support to rhc-chk (fotios@redhat.com)

* Wed Nov 23 2011 Dan McPherson <dmcphers@redhat.com> 0.82.16-1
- further trimming the output of rhc-create-app (abhgupta@redhat.com)

* Tue Nov 22 2011 Dan McPherson <dmcphers@redhat.com> 0.82.15-1
- Added 2 checks to prevent errors if password not specified or kfile does not
  exist (fotios@redhat.com)

* Tue Nov 22 2011 Alex Boone <aboone@redhat.com> 0.82.14-1
- 

* Tue Nov 22 2011 Dan McPherson <dmcphers@redhat.com> 0.82.13-1
- need some output on ctl-app (dmcphers@redhat.com)
- Added test to attempt to SSH into all of the user's apps (fotios@redhat.com)
- Moved YAML from __END__ (fotios@redhat.com)

* Tue Nov 22 2011 Alex Boone <aboone@redhat.com> 0.82.12-1
- Use rubygem-json for RHEL5 (aboone@redhat.com)
- Degrade to Rake::GemPackageTask when Gem::PackageTask is not supported
  (aboone@redhat.com)
- Lower requirement on ruby version to 1.8.5 (aboone@redhat.com)

* Mon Nov 21 2011 Dan McPherson <dmcphers@redhat.com> 0.82.11-1
- reducing the number of messages being output for the rhc-create-app command
  (abhgupta@redhat.com)
- Moved messages to __END__. Added ssh-agent test. Moved message rendering to
  its own function (fotios@redhat.com)

* Mon Nov 21 2011 Dan McPherson <dmcphers@redhat.com>
- reducing the number of messages being output for the rhc-create-app command
  (abhgupta@redhat.com)
- Moved messages to __END__. Added ssh-agent test. Moved message rendering to
  its own function (fotios@redhat.com)

* Mon Nov 21 2011 Dan McPherson <dmcphers@redhat.com>
- reducing the number of messages being output for the rhc-create-app command
  (abhgupta@redhat.com)
- Moved messages to __END__. Added ssh-agent test. Moved message rendering to
  its own function (fotios@redhat.com)

* Sat Nov 19 2011 Dan McPherson <dmcphers@redhat.com> 0.82.8-1
- Refactored rhc-chk to use Test::Unit for tests (fotios@redhat.com)

* Sat Nov 19 2011 Dan McPherson <dmcphers@redhat.com>
- Refactored rhc-chk to use Test::Unit for tests (fotios@redhat.com)

* Thu Nov 17 2011 Dan McPherson <dmcphers@redhat.com> 0.82.6-1
- fail gracefully on ctrl+c from destroy y/n prompt (dmcphers@redhat.com)

* Wed Nov 16 2011 Dan McPherson <dmcphers@redhat.com> 0.82.5-1
- add better command details to man page (dmcphers@redhat.com)

* Tue Nov 15 2011 Dan McPherson <dmcphers@redhat.com> 0.82.4-1
- adding tidy option to rhc-ctl-app (dmcphers@redhat.com)

* Mon Nov 14 2011 Dan McPherson <dmcphers@redhat.com> 0.82.3-1
- match client and server messages (dmcphers@redhat.com)
- error sooner on app already exists (dmcphers@redhat.com)

* Sat Nov 12 2011 Dan McPherson <dmcphers@redhat.com> 0.82.2-1
- doc update (dmcphers@redhat.com)

* Thu Nov 10 2011 Dan McPherson <dmcphers@redhat.com> 0.82.1-1
- bump spec numbers (dmcphers@redhat.com)

* Wed Nov 09 2011 Dan McPherson <dmcphers@redhat.com> 0.81.14-1
- man page fixes (dmcphers@redhat.com)

* Wed Nov 09 2011 Dan McPherson <dmcphers@redhat.com> 0.81.13-1
- Automatic commit of package [rhc] release [0.81.12-1]. (aboone@redhat.com)
- Automatic commit of package [rhc] release [0.81.12-1]. (dmcphers@redhat.com)
- Bug 752341 (dmcphers@redhat.com)
- update man page with alias logic (dmcphers@redhat.com)
- Typo in message (mhicks@redhat.com)
- fix not to throw exception on ctl+c from password (dmcphers@redhat.com)

* Tue Nov 08 2011 Alex Boone <aboone@redhat.com> 0.81.12-1
- cleanup (dmcphers@redhat.com)

* Mon Nov 07 2011 Dan McPherson <dmcphers@redhat.com> 0.81.11-1
- move create app message down and ruby 1.8.6 compatibility
  (dmcphers@redhat.com)

* Sun Nov 06 2011 Dan McPherson <dmcphers@redhat.com> 0.81.10-1
- more error handling (dmcphers@redhat.com)

* Sat Nov 05 2011 Dan McPherson <dmcphers@redhat.com> 0.81.9-1
- missed an if (dmcphers@redhat.com)

* Sat Nov 05 2011 Dan McPherson <dmcphers@redhat.com> 0.81.8-1
- adding auto enable jenkins (dmcphers@redhat.com)
- hide user uuid to avoid confusion (dmcphers@redhat.com)
- rhc-chk needs to default back to id_rsa like create app (dmcphers@redhat.com)

* Fri Nov 04 2011 Dan McPherson <dmcphers@redhat.com> 0.81.7-1
- move messages to a more appropriate place (dmcphers@redhat.com)
- 749758 (dmcphers@redhat.com)
- Merge branch 'master' of github.com:openshift/os-client-tools
  (mmcgrath@redhat.com)
- Added no-dns feature (mmcgrath@redhat.com)

* Fri Nov 04 2011 Dan McPherson <dmcphers@redhat.com> 0.81.6-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (mmcgrath@redhat.com)
- Ignore alias check when no command is specified (mmcgrath@redhat.com)

* Thu Nov 03 2011 Dan McPherson <dmcphers@redhat.com> 0.81.5-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (mmcgrath@redhat.com)
- Adding alias checks (mmcgrath@redhat.com)

* Thu Nov 03 2011 Dan McPherson <dmcphers@redhat.com> 0.81.4-1
- better error handling around creating git parent (dmcphers@redhat.com)

* Fri Oct 28 2011 Dan McPherson <dmcphers@redhat.com> 0.81.3-1
- single quotes are better (dmcphers@redhat.com)
- allow actual booleans for debug and alter (dmcphers@redhat.com)
- Bug 749737 (dmcphers@redhat.com)

* Thu Oct 27 2011 Dan McPherson <dmcphers@redhat.com> 0.81.2-1
- fix doc (dmcphers@redhat.com)
- update API doc as well (dmcphers@redhat.com)
- stop passing cartridge to server for normal ctl commands (except for
  embedded) (dmcphers@redhat.com)
- Bug 749464 (dmcphers@redhat.com)

* Thu Oct 27 2011 Dan McPherson <dmcphers@redhat.com> 0.81.1-1
- bump spec number (dmcphers@redhat.com)

* Wed Oct 26 2011 Dan McPherson <dmcphers@redhat.com> 0.80.5-1
- Add better messaging around the format of the archive (dmcphers@redhat.com)

* Wed Oct 26 2011 Dan McPherson <dmcphers@redhat.com> 0.80.4-1
- bug 749097 (dmcphers@redhat.com)
- error message correction (dmcphers@redhat.com)

* Fri Oct 21 2011 Dan McPherson <dmcphers@redhat.com> 0.80.3-1
- up app name limit to 32 (dmcphers@redhat.com)

* Wed Oct 19 2011 Dan McPherson <dmcphers@redhat.com> 0.80.2-1
- add force-stop (dmcphers@redhat.com)

* Thu Oct 13 2011 Dan McPherson <dmcphers@redhat.com> 0.80.1-1
- bump spec version (dmcphers@redhat.com)

* Tue Oct 11 2011 Dan McPherson <dmcphers@redhat.com> 0.79.5-1
- Bug 739432 (dmcphers@redhat.com)
- Bug 744493 (dmcphers@redhat.com)

* Mon Oct 10 2011 Dan McPherson <dmcphers@redhat.com> 0.79.4-1
- leave timeout disabled for now (accept default) (dmcphers@redhat.com)
- bug 755660 (dmcphers@redhat.com)

* Sun Oct 09 2011 Dan McPherson <dmcphers@redhat.com> 0.79.3-1
- Bug 744369 (dmcphers@redhat.com)

* Tue Oct 04 2011 Dan McPherson <dmcphers@redhat.com> 0.79.2-1
- debug cleanups... (jim@jaguNET.com)
- Update doccos (jim@jaguNET.com)
- Make the connection timeout user configurable (jim@jaguNET.com)

* Thu Sep 29 2011 Dan McPherson <dmcphers@redhat.com> 0.79.1-1
- cleanup merge (dmcphers@redhat.com)
- add --config to man pages (dmcphers@redhat.com)
- Man pages (jim@jaguNET.com)

* Wed Sep 28 2011 Dan McPherson <dmcphers@redhat.com> 0.77.8-1
- use methods to find key to check for rhc-chk (dmcphers@redhat.com)

* Tue Sep 27 2011 Dan McPherson <dmcphers@redhat.com> 0.77.7-1
- add rhc-chk to executables and add --config option (dmcphers@redhat.com)

* Tue Sep 27 2011 Dan McPherson <dmcphers@redhat.com> 0.77.6-1
- use --config setting for updates as well as reads (dmcphers@redhat.com)

* Tue Sep 27 2011 Dan McPherson <dmcphers@redhat.com> 0.77.5-1
- add pkg to gitignore (dmcphers@redhat.com)

* Tue Sep 27 2011 Dan McPherson <dmcphers@redhat.com> 0.77.4-1
- remove rhlogin length check (dmcphers@redhat.com)
- match working names (jim@jaguNET.com)
- remove old (jim@jaguNET.com)
- and replace (jim@jaguNET.com)
- update (jim@jaguNET.com)
- fold in chcker (jim@jaguNET.com)
- Abtract out the --config path check... reuse (jim@jaguNET.com)
- Allow user to specify config-file directly via --config opt (jim@jaguNET.com)
- updated (jim@jaguNET.com)

* Mon Sep 12 2011 Dan McPherson <dmcphers@redhat.com> 0.77.3-1
- Merge branch 'master' of ssh://git1.ops.rhcloud.com/srv/git/li
  (mmcgrath@redhat.com)
- Added rhc-chk (mmcgrath@redhat.com)

* Fri Sep 09 2011 Matt Hicks <mhicks@redhat.com> 0.77.2-1
- No more dev here for express client tools (jimjag@redhat.com)

* Thu Sep 01 2011 Dan McPherson <dmcphers@redhat.com> 0.77.1-1
- bump spec numbers (dmcphers@redhat.com)

* Wed Aug 31 2011 Dan McPherson <dmcphers@redhat.com> 0.76.7-1
- bz726646 patch attempt #2 (markllama@redhat.com)

* Mon Aug 29 2011 Dan McPherson <dmcphers@redhat.com> 0.76.6-1
- Revert "Revert "reverse patched to removed commit
  d34abaacc98e5b8f5387eff71064c4616a61f24b"" (markllama@gmail.com)
- Revert "reverse patched to removed commit
  d34abaacc98e5b8f5387eff71064c4616a61f24b" (markllama@redhat.com)

* Mon Aug 29 2011 Dan McPherson <dmcphers@redhat.com> 0.76.5-1
- reverse patched to removed commit d34abaacc98e5b8f5387eff71064c4616a61f24b
  (markllama@redhat.com)

* Mon Aug 29 2011 Dan McPherson <dmcphers@redhat.com> 0.76.4-1
- bz736646 - allow pty for ssh commands (markllama@redhat.com)

* Thu Aug 25 2011 Dan McPherson <dmcphers@redhat.com> 0.76.3-1
- change rsa_key_file to ssh_key_file and change not found to warning
  (dmcphers@redhat.com)

* Wed Aug 24 2011 Dan McPherson <dmcphers@redhat.com> 0.76.2-1
- add to client tools the ability to specify your rsa key file as well as
  default back to id_rsa as a last resort (dmcphers@redhat.com)

* Fri Aug 19 2011 Matt Hicks <mhicks@redhat.com> 0.76.1-1
- bump spec numbers (dmcphers@redhat.com)

* Wed Aug 17 2011 Dan McPherson <dmcphers@redhat.com> 0.75.9-1
- Another message tweak (mhicks@redhat.com)
- change wording from pull to clone (dmcphers@redhat.com)
- Adding some more information to the warning message (mhicks@redhat.com)
- Making DNS timeout non-fatal (mhicks@redhat.com)

* Wed Aug 17 2011 Dan McPherson <dmcphers@redhat.com> 0.75.8-1
- wording change (dmcphers@redhat.com)

* Tue Aug 16 2011 Dan McPherson <dmcphers@redhat.com> 0.75.7-1
- doc update (dmcphers@redhat.com)

* Tue Aug 16 2011 Dan McPherson <dmcphers@redhat.com> 0.75.6-1
- add better message to libra_id_rsa missing on the client
  (dmcphers@redhat.com)

* Tue Aug 16 2011 Dan McPherson <dmcphers@redhat.com> 0.75.5-1
- cleanup how we call snapshot (dmcphers@redhat.com)
- prepping for UUID prefixed backups (mmcgrath@redhat.com)

* Sun Aug 14 2011 Dan McPherson <dmcphers@redhat.com> 0.75.4-1
- doc updates (dmcphers@redhat.com)
- restore error handling (dmcphers@redhat.com)
- functional restore (dmcphers@redhat.com)
- Use \d regex patter for clarity pull broker and server-side api from any/all
  responses if possible protect against parse errors (jimjag@redhat.com)

* Thu Aug 11 2011 Matt Hicks <mhicks@redhat.com> 0.75.3-1
- If broker provides API and broker version, client should display
  (jimjag@redhat.com)

* Tue Aug 09 2011 Dan McPherson <dmcphers@redhat.com> 0.75.2-1
- get restore to a basic functional level (dmcphers@redhat.com)
- pub (jimjag@redhat.com)
- client-side API in req (jimjag@redhat.com)

* Mon Aug 08 2011 Dan McPherson <dmcphers@redhat.com> 0.75.1-1
- restore work in progress (dmcphers@redhat.com)

* Thu Jul 21 2011 Dan McPherson <dmcphers@redhat.com> 0.74.5-1
- doc updates (dmcphers@redhat.com)

* Mon Jul 18 2011 Dan McPherson <dmcphers@redhat.com> 0.74.4-1
- api update (dmcphers@redhat.com)
- Block it (jimjag@redhat.com)
- Adding a script to build the gem with json_pure (mhicks@redhat.com)
- force as block (jimjag@redhat.com)
- Adding the ability to force json_pure dependency (mhicks@redhat.com)

* Fri Jul 15 2011 Dan McPherson <dmcphers@redhat.com> 0.74.3-1
- bug 721296 (dmcphers@redhat.com)
- Bug 721236 (dmcphers@redhat.com)

* Tue Jul 12 2011 Dan McPherson <dmcphers@redhat.com> 0.74.2-1
- Automatic commit of package [rhc] release [0.74.1-1]. (dmcphers@redhat.com)
- bumping spec numbers (dmcphers@redhat.com)
- add options to tail-files (dmcphers@redhat.com)
- Automatic commit of package [rhc] release [0.73.14-1]. (dmcphers@redhat.com)
- add retries to login/logout and doc updates (dmcphers@redhat.com)
- Automatic commit of package [rhc] release [0.73.13-1]. (dmcphers@redhat.com)
- remove embed param passing to broker and doc updates (dmcphers@redhat.com)
- API updates (dmcphers@redhat.com)
- Automatic commit of package [rhc] release [0.73.12-1]. (dmcphers@redhat.com)
- bug 719510 (dmcphers@redhat.com)
- Remove non-tested depende (jimjag@redhat.com)
- Automatic commit of package [rhc] release [0.73.11-1]. (dmcphers@redhat.com)
- Bug 719219 (dmcphers@redhat.com)
- Automatic commit of package [rhc] release [0.73.10-1]. (dmcphers@redhat.com)
- up (jimjag@redhat.com)
- Merge branch 'master' of ssh://git1.ops.rhcloud.com/srv/git/li
  (jimjag@redhat.com)
- force spec file to use darwin (jimjag@redhat.com)
- standardize message (dmcphers@redhat.com)
- Automatic commit of package [rhc] release [0.73.9-1]. (dmcphers@redhat.com)
- Allowing rhc-tail-files to operate on the ~/ dir instead of ~/app
  (mmcgrath@redhat.com)
- Automatic commit of package [rhc] release [0.73.8-1]. (edirsh@redhat.com)
- Merge branch 'master' of ssh://git1.ops.rhcloud.com/srv/git/li
  (mmcgrath@redhat.com)
- fixing mysql version in example (mmcgrath@redhat.com)
- Automatic commit of package [rhc] release [0.73.7-1]. (dmcphers@redhat.com)
- cart list fixes from embed (dmcphers@redhat.com)
- Automatic commit of package [rhc] release [0.73.6-1]. (dmcphers@redhat.com)
- cleanup (dmcphers@redhat.com)
- perf improvements for how/when we look up the valid cart types on the server
  (dmcphers@redhat.com)
- move health check path to server (dmcphers@redhat.com)
- Automatic commit of package [rhc] release [0.73.5-1]. (dmcphers@redhat.com)
- fixing merge from Dan (mmcgrath@redhat.com)
- fixed formatting and embedded display (mmcgrath@redhat.com)
- Automatic commit of package [rhc] release [0.73.4-1]. (dmcphers@redhat.com)
- handle embed or command not passed (dmcphers@redhat.com)
- Adding embedded list support (mmcgrath@redhat.com)
- Automatic commit of package [rhc] release [0.73.3-1]. (mhicks@redhat.com)
- Merge branch 'master' of git1.ops.rhcloud.com:/srv/git/li (mhicks@redhat.com)
- allow messsages from cart to client (dmcphers@redhat.com)
- Updating to new Rake tasks to avoid deprecation warning (mhicks@redhat.com)
- Adding embed support (mmcgrath@redhat.com)
- Added embedded list (mmcgrath@redhat.com)

* Mon Jul 11 2011 Dan McPherson <dmcphers@redhat.com> 0.74.1-1
- bumping spec numbers (dmcphers@redhat.com)
- add options to tail-files (dmcphers@redhat.com)

* Thu Jul 07 2011 Dan McPherson <dmcphers@redhat.com> 0.73.14-1
- add retries to login/logout and doc updates (dmcphers@redhat.com)

* Thu Jul 07 2011 Dan McPherson <dmcphers@redhat.com> 0.73.13-1
- remove embed param passing to broker and doc updates (dmcphers@redhat.com)
- API updates (dmcphers@redhat.com)

* Thu Jul 07 2011 Dan McPherson <dmcphers@redhat.com> 0.73.12-1
- bug 719510 (dmcphers@redhat.com)
- Remove non-tested depende (jimjag@redhat.com)

* Wed Jul 06 2011 Dan McPherson <dmcphers@redhat.com> 0.73.11-1
- Bug 719219 (dmcphers@redhat.com)

* Wed Jul 06 2011 Dan McPherson <dmcphers@redhat.com> 0.73.10-1
- up (jimjag@redhat.com)
- Merge branch 'master' of ssh://git1.ops.rhcloud.com/srv/git/li
  (jimjag@redhat.com)
- force spec file to use darwin (jimjag@redhat.com)
- standardize message (dmcphers@redhat.com)

* Tue Jul 06 2011 Jim Jagielski <jimjag@redhat.com> 0.73.10-1
- json_pure dependencies
  (mmcgrath@redhat.com)

* Tue Jul 05 2011 Dan McPherson <dmcphers@redhat.com> 0.73.9-1
- Allowing rhc-tail-files to operate on the ~/ dir instead of ~/app
  (mmcgrath@redhat.com)

* Fri Jul 01 2011 Emily Dirsh <edirsh@redhat.com> 0.73.8-1
- Merge branch 'master' of ssh://git1.ops.rhcloud.com/srv/git/li
  (mmcgrath@redhat.com)
- fixing mysql version in example (mmcgrath@redhat.com)

* Thu Jun 30 2011 Dan McPherson <dmcphers@redhat.com> 0.73.7-1
- cart list fixes from embed (dmcphers@redhat.com)

* Thu Jun 30 2011 Dan McPherson <dmcphers@redhat.com> 0.73.6-1
- cleanup (dmcphers@redhat.com)
- perf improvements for how/when we look up the valid cart types on the server
  (dmcphers@redhat.com)
- move health check path to server (dmcphers@redhat.com)

* Wed Jun 29 2011 Dan McPherson <dmcphers@redhat.com> 0.73.5-1
- fixing merge from Dan (mmcgrath@redhat.com)
- fixed formatting and embedded display (mmcgrath@redhat.com)
- Adding embedded list support (mmcgrath@redhat.com)

* Wed Jun 29 2011 Dan McPherson <dmcphers@redhat.com> 0.73.4-1
- handle embed or command not passed (dmcphers@redhat.com)

* Tue Jun 28 2011 Matt Hicks <mhicks@redhat.com> 0.73.3-1
- Merge branch 'master' of git1.ops.rhcloud.com:/srv/git/li (mhicks@redhat.com)
- allow messsages from cart to client (dmcphers@redhat.com)
- Updating to new Rake tasks to avoid deprecation warning (mhicks@redhat.com)
- Adding embed support (mmcgrath@redhat.com)
- Added embedded list (mmcgrath@redhat.com)

* Mon Jun 27 2011 Dan McPherson <dmcphers@redhat.com> 0.73.2-1
- force evaluation (jimjag@redhat.com)
- better structure... (jimjag@redhat.com)
- adjust for Fed13 and RHEL5 (no elsif?) (jimjag@redhat.com)

* Mon Jun 27 2011 Dan McPherson <dmcphers@redhat.com> 0.73.1-1
- Fed13 and RHEL5 use json_pure
- bump spec numbers (dmcphers@redhat.com)
- json_pure for 1.8.6, Darwin and Windows. Thx mhicks for the pointer!
  (jimjag@redhat.com)
- Note that others may exist... suggest -h (jimjag@redhat.com)
- cleanup for 1.8.6 (jimjag@redhat.com)
- 1.8.6 no have start_with (jimjag@redhat.com)

* Thu Jun 23 2011 Dan McPherson <dmcphers@redhat.com> 0.72.29-1
- no more need Xcode... show how (jimjag@redhat.com)

* Thu Jun 23 2011 Dan McPherson <dmcphers@redhat.com> 0.72.28-1
- 

* Thu Jun 23 2011 Dan McPherson <dmcphers@redhat.com> 0.72.27-1
- switch timeout back to 10s (dmcphers@redhat.com)

* Wed Jun 22 2011 Dan McPherson <dmcphers@redhat.com> 0.72.26-1
- trying a larger timeout (dmcphers@redhat.com)

* Wed Jun 22 2011 Dan McPherson <dmcphers@redhat.com> 0.72.25-1
- API cleanup (dmcphers@redhat.com)

* Tue Jun 21 2011 Dan McPherson <dmcphers@redhat.com> 0.72.24-1
- fix typo (dmcphers@redhat.com)

* Sat Jun 18 2011 Dan McPherson <dmcphers@redhat.com> 0.72.23-1
- test case fix (dmcphers@redhat.com)

* Fri Jun 17 2011 Dan McPherson <dmcphers@redhat.com> 0.72.22-1
- Merge branch 'master' of ssh://git1.ops.rhcloud.com/srv/git/li
  (jimjag@redhat.com)
- wrong commit/revert (jimjag@redhat.com)

* Fri Jun 17 2011 Dan McPherson <dmcphers@redhat.com> 0.72.21-1
- userland info message update... (jimjag@redhat.com)
- Allow the cartridge_post to handle invalid carts for us. (jimjag@redhat.com)

* Thu Jun 16 2011 Dan McPherson <dmcphers@redhat.com> 0.72.20-1
- add error if invalid cart sent to server (dmcphers@redhat.com)

* Wed Jun 15 2011 Dan McPherson <dmcphers@redhat.com> 0.72.19-1
- 

* Wed Jun 15 2011 Dan McPherson <dmcphers@redhat.com> 0.72.18-1
- 

* Wed Jun 15 2011 Dan McPherson <dmcphers@redhat.com> 0.72.17-1
- 

* Wed Jun 15 2011 Dan McPherson <dmcphers@redhat.com> 0.72.16-1
- 

* Wed Jun 15 2011 Dan McPherson <dmcphers@redhat.com> 0.72.15-1
- api doc updates (dmcphers@redhat.com)
- api doc updates (dmcphers@redhat.com)
- add cart_types param to cartlist call (dmcphers@redhat.com)
- No need for roundtrip if they provided cartridge.. the server will let us
  know if not accepted. (jimjag@redhat.com)
- Inform user that we need to contact the RHCloud server Handle errors from
  server in a somewhat more user-friendly way (jimjag@redhat.com)
- simple prettyfication -> ((required)) --> (required) (jimjag@redhat.com)

* Tue Jun 14 2011 Matt Hicks <mhicks@redhat.com> 0.72.14-1
- rename to make more sense... (jimjag@redhat.com)
- Merge branch 'master' of ssh://git1.ops.rhcloud.com/srv/git/li
  (jimjag@redhat.com)
- remove pw from deconfigure on error call (dmcphers@redhat.com)
- Use as symbols (jimjag@redhat.com)
- minor fixes (dmcphers@redhat.com)
- Merge branch 'master' of ssh://git1.ops.rhcloud.com/srv/git/li
  (jimjag@redhat.com)
- method name (jimjag@redhat.com)
- minor fixes (dmcphers@redhat.com)
- parse from array (jimjag@redhat.com)
- Pass string (jimjag@redhat.com)
- No more convert (jimjag@redhat.com)
- cart_list factor returns a string now, with cartridges sep by '|'
  (jimjag@redhat.com)
- Adjust for JSON (jimjag@redhat.com)
- past one level (jimjag@redhat.com)
- and not a key (jimjag@redhat.com)
- pull in carts from result (jimjag@redhat.com)
- force debug for now (jimjag@redhat.com)
- use as boolean (jimjag@redhat.com)
- simple name change (jimjag@redhat.com)
- be consistent (jimjag@redhat.com)
- Pass debug flag (jimjag@redhat.com)
- Scoping issues (jimjag@redhat.com)
- pull into client tools cartinfo (jimjag@redhat.com)

* Fri Jun 10 2011 Matt Hicks <mhicks@redhat.com> 0.72.13-1
- give better message when running rhc-create-domain with alter first
  (dmcphers@redhat.com)

* Fri Jun 10 2011 Matt Hicks <mhicks@redhat.com> 0.72.12-1
- bug 712276 (dmcphers@redhat.com)

* Fri Jun 10 2011 Matt Hicks <mhicks@redhat.com> 0.72.11-1
- Added applicatino name (mmcgrath@redhat.com)

* Thu Jun 09 2011 Dan McPherson <dmcphers@redhat.com> 0.72.10-1
- bug 707857 (dmcphers@redhat.com)

* Thu Jun 09 2011 Matt Hicks <mhicks@redhat.com> 0.72.9-1
- Bug 706353 (dmcphers@redhat.com)
- cleanup (dmcphers@redhat.com)
- Bug 707857 (dmcphers@redhat.com)
- Bug 705703 (dmcphers@redhat.com)
- improve terminology with rhlogin in usage and man pages (dmcphers@redhat.com)

* Wed Jun 08 2011 Dan McPherson <dmcphers@redhat.com> 0.72.8-1
- 

* Wed Jun 08 2011 Dan McPherson <dmcphers@redhat.com> 0.72.7-1
- Bug 711685 (dmcphers@redhat.com)
- fix rhc-snapshot (dmcphers@redhat.com)

* Tue Jun 07 2011 Matt Hicks <mhicks@redhat.com> 0.72.6-1
- Added a curl example (mmcgrath@redhat.com)
- Adding more explicit references in API doc (mmcgrath@redhat.com)

* Fri Jun 03 2011 Matt Hicks <mhicks@redhat.com> 0.72.4-1
- fix breakge no mo pure (jimjag@redhat.com)
- revert (jimjag@redhat.com)
- Move to json/pure for client side (jimjag@redhat.com)
- Adding json string (mmcgrath@redhat.com)
- Added API returns (mmcgrath@redhat.com)
- Switching to json_pure for Mac / Windows (mhicks@redhat.com)

* Wed Jun 01 2011 Dan McPherson <dmcphers@redhat.com> 0.72.3-1
- app-uuid patch from dev/markllama/app-uuid
  69b077104e3227a73cbf101def9279fe1131025e (markllama@gmail.com)

* Tue May 31 2011 Matt Hicks <mhicks@redhat.com> 0.72.2-1
- Bug 707488 (dmcphers@redhat.com)