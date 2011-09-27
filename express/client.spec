%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)

Summary:       Multi-tenant cloud management system client tools
Name:          rhc
Version:       0.77.6
Release:       1%{?dist}
Group:         Network/Daemons
License:       MIT
URL:           http://openshift.redhat.com
Source0:       rhc-%{version}.tar.gz

BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildRequires: rubygem-rake
BuildRequires: rubygem-rspec
Requires:      ruby >= 1.8.6
Requires:      rubygem-parseconfig

%if 0%{?fedora} == 13
%define jpure 1
%endif
%if 0%{?rhel} == 5
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
for f in bin/rhc-*
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
rake package

mkdir -p .%{gemdir}
gem install --install-dir $RPM_BUILD_ROOT/%{gemdir} --bindir $RPM_BUILD_ROOT/%{_bindir} --local -V --force --rdoc \
     pkg/rhc-%{version}.gem

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc doc/USAGE.txt
%{_bindir}/rhc-chk
%{_bindir}/rhc-create-app
%{_bindir}/rhc-create-domain
%{_bindir}/rhc-user-info
%{_bindir}/rhc-ctl-app
%{_bindir}/rhc-snapshot
%{_bindir}/rhc-tail-files
%{_mandir}/man1/rhc-*
%{_mandir}/man5/express*
%{gemdir}/gems/rhc-%{version}/
%{gemdir}/cache/rhc-%{version}.gem
%{gemdir}/doc/rhc-%{version}
%{gemdir}/specifications/rhc-%{version}.gemspec
%config(noreplace) %{_sysconfdir}/openshift/express.conf

%changelog
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

