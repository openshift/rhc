%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%define gemversion %(echo %{version} | cut -d'.' -f1-3)

Summary:       OpenShift client management tools
Name:          rhc
Version: 1.30.1
Release:       1%{?dist}
Group:         Network/Daemons
License:       ASL 2.0
URL:           http://openshift.redhat.com
Source0:       rhc-%{version}.tar.gz

BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildRequires: ruby >= 1.8.5
BuildRequires: rubygems
BuildRequires: rubygem-rdoc
BuildRequires: ruby-irb
Requires:      ruby >= 1.8.5
Requires:      rubygem-parseconfig
Requires:      rubygem-httpclient
Requires:      rubygem-test-unit
Requires:      rubygem-net-ssh
Requires:      rubygem-net-scp
Requires:      ruby193-rubygem-net-scp
Requires:      rubygem-net-ssh-multi
Requires:      rubygem-archive-tar-minitar
Requires:      rubygem-commander
Requires:      rubygem-open4
Requires:      git
%if 0%{?fedora} >= 19 || 0%{?rhel} >= 7
Requires:      rubygem-net-ssh-multi
%endif
Obsoletes:     rhc-rest
Provides:      rubygem-rhc

BuildArch:     noarch

%description
Provides OpenShift client libraries.

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
LC_ALL=en_US.UTF-8 gem build rhc.gemspec

mkdir -p .%{gemdir}
# Ignore dependencies here because these will be handled by rpm 
gem install --install-dir $RPM_BUILD_ROOT/%{gemdir} --bindir $RPM_BUILD_ROOT/%{_bindir} --local -V --force --rdoc --ignore-dependencies \
     rhc-%{version}.gem

# Copy the bash autocompletion script
mkdir -p "$RPM_BUILD_ROOT/etc/bash_completion.d/"
cp autocomplete/rhc_bash $RPM_BUILD_ROOT/etc/bash_completion.d/rhc

cp LICENSE $RPM_BUILD_ROOT/%{gemdir}/gems/rhc-%{version}/LICENSE
cp COPYRIGHT $RPM_BUILD_ROOT/%{gemdir}/gems/rhc-%{version}/COPYRIGHT

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc LICENSE
%doc COPYRIGHT
%{_bindir}/rhc
%{_mandir}/man1/rhc*
%{_mandir}/man5/express*
%{gemdir}/gems/rhc-%{version}/
%{gemdir}/cache/rhc-%{version}.gem
%{gemdir}/doc/rhc-%{version}
%{gemdir}/specifications/rhc-%{version}.gemspec
%config(noreplace) %{_sysconfdir}/openshift/express.conf
%attr(0644,-,-) /etc/bash_completion.d/rhc

%changelog
* Thu Aug 21 2014 Adam Miller <admiller@redhat.com> 1.30.1-1
- Merge pull request #644 from liggitt/ichi-the-one-master
  (dmcphers+openshiftbot@redhat.com)
- Rename and hide headers option, add spec tests (jliggitt@redhat.com)
- bump_minor_versions for sprint 50 (admiller@redhat.com)
- Using headers with RHC (sara@otvmi300s.priv.atos.fr)

* Tue Aug 19 2014 Adam Miller <admiller@redhat.com> 1.29.7-1
- Bug 1126388 - when displaying servers will warn if a given server is not yet
  configured (contact@fabianofranz.com)

* Fri Aug 15 2014 Troy Dawson <tdawson@redhat.com> 1.29.6-1
- Merge pull request #636 from liggitt/rework_token_fallback
  (dmcphers+openshiftbot@redhat.com)
- Bug 1128987 - prevent rhc from needlessly regenerating tokens with x509 auth
  (bleanhar@redhat.com)
- Use cert as user_key for token store hash for x509 (jliggitt@redhat.com)
- Rework token fallback (jliggitt@redhat.com)

* Thu Aug 14 2014 Adam Miller <admiller@redhat.com> 1.29.5-1
- Merge pull request #641 from fabianofranz/dev/207
  (dmcphers+openshiftbot@redhat.com)
- [origin-ui-207] Handle user region selection availability
  (contact@fabianofranz.com)

* Wed Aug 13 2014 Adam Miller <admiller@redhat.com> 1.29.4-1
- Bug 1128986 - Missing "--ssl-client-key-file" option in the help message of
  'rhc server add/configure' (bleanhar@redhat.com)

* Tue Aug 12 2014 Adam Miller <admiller@redhat.com> 1.29.3-1
- Merge pull request #639 from fabianofranz/bugs/1126388
  (dmcphers+openshiftbot@redhat.com)
- Bug 1126388 - removed warning message (contact@fabianofranz.com)

* Mon Aug 11 2014 Adam Miller <admiller@redhat.com> 1.29.2-1
- Bug 1126388 - only warns if unconfigured server comes from conf files
  (contact@fabianofranz.com)

* Fri Aug 08 2014 Adam Miller <admiller@redhat.com> 1.29.1-1
- bump_minor_versions for sprint 49 (admiller@redhat.com)

* Fri Aug 08 2014 Adam Miller <admiller@redhat.com> 1.28.6-1
- Bug 1126388 - must properly handle express.conf server missing on servers.yml
  (contact@fabianofranz.com)

* Wed Jul 30 2014 Adam Miller <admiller@redhat.com> 1.28.5-1
- Bug 1124343 - show|list domain must tolerate servers with no membership
  support (contact@fabianofranz.com)

* Mon Jul 28 2014 Adam Miller <admiller@redhat.com> 1.28.4-1
- Merge pull request #634 from fabianofranz/bugs/1067874
  (dmcphers+openshiftbot@redhat.com)
- Bug 1067874 - fixes rhc server status messages (contact@fabianofranz.com)

* Fri Jul 25 2014 Troy Dawson <tdawson@redhat.com> 1.28.3-1
- Merge pull request #632 from fabianofranz/bugs/1091071
  (dmcphers+openshiftbot@redhat.com)
- Merge pull request #486 from brenton/x509 (dmcphers+openshiftbot@redhat.com)
- Bug 1091071 - properly displays haproxy on app gears
  (contact@fabianofranz.com)
- Merge pull request #633 from fabianofranz/bugs/1082973
  (dmcphers+openshiftbot@redhat.com)
- Bug 1082973 - improved exit message when there are warnings from broker
  (contact@fabianofranz.com)
- x509 auth (bleanhar@redhat.com)

* Thu Jul 24 2014 Adam Miller <admiller@redhat.com> 1.28.2-1
- Merge pull request #631 from brenton/BZ1122702
  (dmcphers+openshiftbot@redhat.com)
- Merge pull request #629 from liggitt/bug_1112449_skip_ssh_key_check
  (dmcphers+openshiftbot@redhat.com)
- Bug 1112449: Skip key upload prompts if a kerberos key is added to the user's
  account (jliggitt@redhat.com)
- [origin-ui-186] Adding support to regions and zones
  (contact@fabianofranz.com)
- Bug 1122702 - "rhc server add" with --no-use-authorization-tokens does not
  work as expected (bleanhar@redhat.com)

* Fri Jul 18 2014 Adam Miller <admiller@redhat.com> 1.28.1-1
- Merge pull request #628 from liggitt/bug_1110728_rhc_help_autocomplete
  (dmcphers+openshiftbot@redhat.com)
- Bug 1110728: RHC help autocomplete (jliggitt@redhat.com)
- Bug 1118903: Fix typo (jliggitt@redhat.com)
- Merge pull request #626 from fabianofranz/bugs/1118712
  (dmcphers+openshiftbot@redhat.com)
- Bug 1118712 - fixes ssl version parse when adding new servers
  (contact@fabianofranz.com)
- Bug 1117466 - fixes overriding timeout config (contact@fabianofranz.com)
- Bug 1118712 and Bug 1118500 - makes global ssl options explicit on rhc server
  commands (contact@fabianofranz.com)
- Bug 1035632 - added plural version to rhc env and rhc sshkey commands
  (contact@fabianofranz.com)
- bump_minor_versions for sprint 48 (admiller@redhat.com)

* Wed Jul 09 2014 Adam Miller <admiller@redhat.com> 1.27.4-1
- Merge pull request #621 from sferich888/debug_ssh
  (dmcphers+openshiftbot@redhat.com)
- Adding Test and reducing the code needed to make this happen
  (erich@redhat.com)
- Merge branch 'master' into debug_ssh (erich@redhat.com)
- Have rhc --debug also put ssh into debugin mode (erich@redhat.com)

* Wed Jul 09 2014 Adam Miller <admiller@redhat.com> 1.27.3-1
- Merge pull request #620 from jcantrill/1116709_unclear_notificatio_message
  (dmcphers+openshiftbot@redhat.com)
- Bug 1117466 - should not reuse SSL certs from different server configs
  (contact@fabianofranz.com)
- Bug 1116709 - Modified the domain rename message to inform about applications
  that will be created (jcantril@redhat.com)

* Thu Jul 03 2014 Adam Miller <admiller@redhat.com> 1.27.2-1
- Bug 1115386 - remove stray space from cloned app environment variables
  (dcleal@redhat.com)

* Thu Jun 26 2014 Adam Miller <admiller@redhat.com> 1.27.1-1
- Improvements to inline help (contact@fabianofranz.com)
- Adding support to nickname on --server option (contact@fabianofranz.com)
- Bug 1111467 - must preserve configs provided through the wizard when saving
  new server (contact@fabianofranz.com)
- bump_minor_versions for sprint 47 (admiller@redhat.com)

* Thu Jun 19 2014 Adam Miller <admiller@redhat.com> 1.26.7-1
- Merge pull request #610 from
  liggitt/bug_1111090_save_serversyml_from_server_command
  (dmcphers+openshiftbot@redhat.com)
- Prevent --use and --skip-wizard being used together (jliggitt@redhat.com)
- Prevent full config being written to express.conf once servers.yml exists
  (jliggitt@redhat.com)
- Add spec test for creating servers.yml on first add (jliggitt@redhat.com)
- Bug 1111090: Allow setting and changing nickname with only a single server
  (jliggitt@redhat.com)

* Thu Jun 19 2014 Adam Miller <admiller@redhat.com> 1.26.6-1
- Bug 1110961 - should not try to convert server to host (allows ports and
  different schemes) (contact@fabianofranz.com)
- Merge pull request #608 from liggitt/bug_1109865_team_show_owner
  (dmcphers+openshiftbot@redhat.com)
- Fetch members if needed for membership#owner (jliggitt@redhat.com)

* Wed Jun 18 2014 Adam Miller <admiller@redhat.com> 1.26.5-1
- Merge pull request #607 from fabianofranz/master
  (dmcphers+openshiftbot@redhat.com)
- [origin-ui-180] Several code improvements (contact@fabianofranz.com)
- Merge pull request #606 from fabianofranz/master
  (dmcphers+openshiftbot@redhat.com)
- Bug 1110357 - fixes issue with ruby/highline conversion to yaml
  (contact@fabianofranz.com)
- Bug 1110266 - fixes first run of rhc server add (contact@fabianofranz.com)

* Tue Jun 17 2014 Adam Miller <admiller@redhat.com> 1.26.4-1
- [origin-ui-180] will not set server as default when add|configure, adds --use
  option (contact@fabianofranz.com)
- [origin-ui-180] Moved more configs to servers.yml, added server nickname
  suggestions (contact@fabianofranz.com)
- [origin-ui-180] Bug fixes and improvements according to code review
  (contact@fabianofranz.com)
- [origin-ui-180] rhc server feature tests (contact@fabianofranz.com)
- [origin-ui-180] Removing discard_global_option (contact@fabianofranz.com)
- [origin-ui-180] rhc supporting multiple servers (contact@fabianofranz.com)

* Fri Jun 13 2014 Adam Miller <admiller@redhat.com> 1.26.3-1
- Ensure we have free gears available (jliggitt@redhat.com)

* Mon Jun 09 2014 Adam Miller <admiller@redhat.com> 1.26.2-1
- Update RHC to work with HTTPClient >= 2.4.0 (jliggitt@redhat.com)

* Thu Jun 05 2014 Adam Miller <admiller@redhat.com> 1.26.1-1
- Prevent rspec 3.0 from being installed (jdetiber@redhat.com)
- Bug 1103049: Fix typo in member update documentation (jliggitt@redhat.com)
- Bug 1103091: Remove .. check for team names from rhc (jliggitt@redhat.com)
- bump_minor_versions for sprint 46 (admiller@redhat.com)

* Wed May 21 2014 Adam Miller <admiller@redhat.com> 1.25.2-1
- Bug 1095440: Ensure gears are free for scalable test (jliggitt@redhat.com)
- Bug 1073283: Escape URI correctly (jliggitt@redhat.com)
- Add spec test for URL encoding (jliggitt@redhat.com)

* Fri May 16 2014 Adam Miller <admiller@redhat.com> 1.25.1-1
- When cloning app should only copy scaling factors of the cartridge if the app
  is scalable (contact@fabianofranz.com)
- bump_minor_versions for sprint 45 (admiller@redhat.com)

* Tue May 06 2014 Troy Dawson <tdawson@redhat.com> 1.24.3-1
- Bug 1079165 - added warning when removing external cart with zero gears
  (contact@fabianofranz.com)
- Workaround bundler issues (contact@fabianofranz.com)

* Mon May 05 2014 Adam Miller <admiller@redhat.com> 1.24.2-1
- Merge pull request #586 from fabianofranz/bugs/1093166-updates-rest-api-
  to-1.7 (dmcphers+openshiftbot@redhat.com)
- Bug 1081235: Fix RHC rate display (jliggitt@redhat.com)
- Bug 1093166 - increases API client to version 1.7 (contact@fabianofranz.com)

* Fri Apr 25 2014 Adam Miller <admiller@redhat.com> 1.24.1-1
- bump_minor_versions for sprint 44 (admiller@redhat.com)
- Merge pull request #585 from
  liggitt/bug_1090912_handle_global_team_delete_error
  (dmcphers+openshiftbot@redhat.com)
- Update autocomplete (jliggitt@redhat.com)
- Bug 1090912: Handle attempts to delete a global team via RHC
  (jliggitt@redhat.com)
- Bug 1090830: Improve help and syntax help for members command
  (jliggitt@redhat.com)
- Review comments (jliggitt@redhat.com)
- Typo (jliggitt@redhat.com)
- Guard team creation with capability check (jliggitt@redhat.com)
- Fix incorrect feature test (jliggitt@redhat.com)
- Team management via RHC (jliggitt@redhat.com)
- Bug 1089665: Show application members who have their membership via domain
  (jliggitt@redhat.com)

* Thu Apr 17 2014 Troy Dawson <tdawson@redhat.com> 1.23.6-1
- Skip forking output for jruby (jliggitt@redhat.com)

* Thu Apr 17 2014 Troy Dawson <tdawson@redhat.com> 1.23.5-1
- Merge pull request #578 from pravisankar/dev/ravi/fix-rhc-tests
  (dmcphers+openshiftbot@redhat.com)
- Fix cucumber support script: Pick user_register_script_format based on auth
  plugin (rpenta@redhat.com)

* Wed Apr 16 2014 Troy Dawson <tdawson@redhat.com> 1.23.4-1
- Merge pull request #579 from liggitt/always_show_owner
  (dmcphers+openshiftbot@redhat.com)
- Always show the domain or application owner in member list
  (jliggitt@redhat.com)

* Tue Apr 15 2014 Troy Dawson <tdawson@redhat.com> 1.23.3-1
- Merge pull request #577 from liggitt/bug_1086567_handle_implicit_leaving
  (dmcphers+openshiftbot@redhat.com)
- Improve message when searching member teams (jliggitt@redhat.com)
- Bug 1086567: Handle implicit members leaving (jliggitt@redhat.com)

* Mon Apr 14 2014 Troy Dawson <tdawson@redhat.com> 1.23.2-1
- Merge pull request #576 from liggitt/fabianofranz-dev/174
  (dmcphers+openshiftbot@redhat.com)
- Improve documentation, sample usage, grammar, and type validation
  (jliggitt@redhat.com)
- Bug 1086698: Improve examples for update to say that user logins or team ids
  can add members (jliggitt@redhat.com)
- Complete spec coverage of members command (jliggitt@redhat.com)
- Bug 1086227: Improve message when a team cannot be found while adding
  (jliggitt@redhat.com)
- Add spec tests to make sure we use an exact match, handle multiple exact
  matches, use a single case-insensitive match, suggest when there are multiple
  matches, and handle special Regexp characters correctly (jliggitt@redhat.com)
- Update spec tests for member list output (jliggitt@redhat.com)
- Bug 1086138: Show info message when there are no members, reformat member
  output, add --all option to show team members (jliggitt@redhat.com)
- Bug 1086127: update autocomplete script (jliggitt@redhat.com)
- Bug 1086128: Improve syntax to include --type and login,team name,id
  (jliggitt@redhat.com)
- [origin-ui-174] add/remove/update/list teams as members
  (contact@fabianofranz.com)

* Wed Apr 09 2014 Adam Miller <admiller@redhat.com> 1.23.1-1
- Merge pull request #573 from jwforres/latest_rake_breaks_on_ruby18
  (dmcphers+openshiftbot@redhat.com)
- Merge pull request #574 from fabianofranz/master
  (dmcphers+openshiftbot@redhat.com)
- Merge pull request #572 from ShalomPisteuo/fixScpMisspelling
  (dmcphers+openshiftbot@redhat.com)
- bump_minor_versions for sprint 43 (admiller@redhat.com)
- Fixes failing test in rhc/features/core_feature.rb:178
  (contact@fabianofranz.com)
- Latest version of rake breaks bundle install on ruby 1.8.x
  (jforrest@redhat.com)
- Fixing a misspelling. (shalompisteuo@gmail.com)

* Tue Mar 25 2014 Adam Miller <admiller@redhat.com> 1.22.5-1
- [origin-ui-162] surface more information in the UI for external cartridges
  (contact@fabianofranz.com)
- Merge pull request #571 from fabianofranz/master
  (dmcphers+openshiftbot@redhat.com)
- Merge pull request #570 from fabianofranz/bugs/1078684
  (dmcphers+openshiftbot@redhat.com)
- Fixes failing test (was reaching the 3 gears limit)
  (contact@fabianofranz.com)
- Bug 1078684 - fixes rhc help options (contact@fabianofranz.com)

* Mon Mar 24 2014 Adam Miller <admiller@redhat.com> 1.22.4-1
- Bug 1079584: Fix scp option conflict with global option (jliggitt@redhat.com)
- Fix failing test (dmcphers@redhat.com)
- Merge pull request #566 from fabianofranz/dev/163
  (dmcphers+openshiftbot@redhat.com)
- [origin-ui-163] Add support to filter apps you own - 'rhc apps --mine'
  (contact@fabianofranz.com)
- Bug 1073108 - fixes case check when removing cartridges by url
  (contact@fabianofranz.com)

* Tue Mar 18 2014 Adam Miller <admiller@redhat.com> 1.22.3-1
- Merge pull request #553 from fabianofranz/dev/160
  (dmcphers+openshiftbot@redhat.com)
- Updates autocomplete (contact@fabianofranz.com)
- Improved message about scaling when creating --from-app
  (contact@fabianofranz.com)
- Creating --from-app will no longer copy aliases, still warns about it
  (contact@fabianofranz.com)
- Moved check for options dns and git to previous logic
  (contact@fabianofranz.com)
- Changes rhc create-app --from to --from-app (contact@fabianofranz.com)
- [origin-dev-ui-160] Add support to clone app on create: 'rhc create-app
  <clone> --from <existing>' (contact@fabianofranz.com)

* Mon Mar 17 2014 Troy Dawson <tdawson@redhat.com> 1.22.2-1
- Merge pull request #564 from nhr/fix_for_origin
  (dmcphers+openshiftbot@redhat.com)
- Merge pull request #563 from liggitt/require_tmpdir
  (dmcphers+openshiftbot@redhat.com)
- Add SCL dependency for client.spec-based RPM builds (hripps@redhat.com)
- Require tmpdir (jliggitt@redhat.com)

* Fri Mar 14 2014 Adam Miller <admiller@redhat.com> 1.22.1-1
- Update scp.rb (developercorey@users.noreply.github.com)
- Update scp.rb (developercorey@users.noreply.github.com)
- Bug 1073852 fixing traceback with authentication failed message
  (cdaley@redhat.com)
- Bug 1073307: Make error message on download failure more generic
  (jliggitt@redhat.com)
- Bug 1073326: Add scp to rhc autocomplete (jliggitt@redhat.com)
- Bug 1073283: Fix scp when app name is empty or . (jliggitt@redhat.com)
- bump_minor_versions for sprint 42 (admiller@redhat.com)

* Wed Mar 05 2014 Adam Miller <admiller@redhat.com> 1.21.3-1
- Bug 1072721: Fix divide by zero and duplicate messages in rhc scp command
  (jliggitt@redhat.com)

* Mon Mar 03 2014 Adam Miller <admiller@redhat.com> 1.21.2-1
- fix cucumber test cartridge index files (vvitek@redhat.com)
- Use more than 1 word (dmcphers@redhat.com)

* Thu Feb 27 2014 Adam Miller <admiller@redhat.com> 1.21.1-1
- Fixing tests (dmcphers@redhat.com)
- Merge pull request #550 from smarterclayton/add_more_debugging_to_dns_output
  (dmcphers+openshiftbot@redhat.com)
- Report more info about DNS resolution (ccoleman@redhat.com)
- fix feature test - remove obsolete php/ dir (vvitek@redhat.com)
- Bug 1066850 - Fixing urls (dmcphers@redhat.com)
- bump_minor_versions for sprint 41 (admiller@redhat.com)

* Sun Feb 16 2014 Adam Miller <admiller@redhat.com> 1.20.3-1
- Explain automatic updates (ccoleman@redhat.com)

* Mon Feb 10 2014 Adam Miller <admiller@redhat.com> 1.20.2-1
- Cleanup formatting (dmcphers@redhat.com)
- Cleaning spec (dmcphers@redhat.com)
- Merge pull request #539 from jhadvig/mongo_update
  (dmcphers+openshiftbot@redhat.com)
- Merge pull request #536 from fabianofranz/dev/441
  (dmcphers+openshiftbot@redhat.com)
- Removed references to OpenShift forums in several places
  (contact@fabianofranz.com)
- Fix infinite retry logic (jordan@liggitt.net)
- Merge pull request #488 from developercorey/rhc_scp
  (dmcphers+openshiftbot@redhat.com)
- adding Requires:rubygem-net-scp to client.spec (cdaley@redhat.com)
- Net::SSH 2.8.0 raises a different exception on fingerprint errors
  (ccoleman@redhat.com)
- Stop using sort_by! for ruby 1.8.7 (jliggitt@redhat.com)
- Add test for domain with more than 5 members (jliggitt@redhat.com)
- Merge pull request #541 from smarterclayton/show_automatic_updates
  (dmcphers+openshiftbot@redhat.com)
- Show automatic updates if available (ccoleman@redhat.com)
- MongoDB version update to 2.4 (jhadvig@redhat.com)
- fixing issues identified by clayton (cdaley@redhat.com)
- adding rhc scp command for transferring files to and from gears, along with
  associated tests (cdaley@redhat.com)

* Thu Jan 30 2014 Adam Miller <admiller@redhat.com> 1.20.1-1
- Use verbose logging in Net::SSH when in debug mode (jliggitt@redhat.com)
- Merge pull request #537 from fabianofranz/bugs/1058251
  (dmcphers+openshiftbot@redhat.com)
- Bug 1058251 - gear activate requires --all to be applied to all gears
  (contact@fabianofranz.com)
- Bug 1048392 - remove workaround for travis CI failures (jforrest@redhat.com)
- bump_minor_versions for sprint 40 (admiller@redhat.com)

* Thu Jan 09 2014 Troy Dawson <tdawson@redhat.com> 1.19.4-1
- Merge pull request #524 from smarterclayton/authorization_tests
  (dmcphers+openshiftbot@redhat.com)
- Bug 1048392 - force gem to version 2.11.1 so travis CI can run
  (jforrest@redhat.com)
- Merge pull request #532 from liggitt/bug_1046443_stderr_redirect
  (dmcphers+openshiftbot@redhat.com)
- Bug 991250 - changed the behavior of the 'rhc' command called alone to
  display help instead of the wizard if it's not configured
  (contact@fabianofranz.com)
- Review: test 'rhc authorization' directly (ccoleman@redhat.com)
- Fix bug 1046443: Incorrect stderr redirect (jliggitt@redhat.com)
- Bug 991250 - 'rhc' must call wizard with the same context as 'rhc setup'
  (contact@fabianofranz.com)
- Bug 1043291 - using ruby to snapshot restore on mac (tar --wildcards not
  supported) (contact@fabianofranz.com)
- Bug 1041313 - allow all rhc catridge commands to accept a url
  (jforrest@redhat.com)
- Authorization tests (ccoleman@redhat.com)
- net-multi-ssh made it to master (ccoleman@redhat.com)
