%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)

Summary:       OpenShift client management tools
Name:          rhc
Version: 0.96.2
Release:       1%{?dist}
Group:         Network/Daemons
License:       ASL 2.0
URL:           http://openshift.redhat.com
Source0:       rhc-%{version}.tar.gz

BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildRequires: rubygem-rake
BuildRequires: rubygem-rspec
BuildRequires: rubygem-webmock
BuildRequires: rubygem-cucumber
Requires:      ruby >= 1.8.5
Requires:      rubygem-parseconfig
Requires:      rubygem-rest-client
Requires:      rubygem-test-unit
Requires:      rubygem-net-ssh
Requires:      rubygem-archive-tar-minitar
Requires:      rubygem-commander
Requires:      git
Obsoletes:     rhc-rest
Provides:      rubygem-rhc

BuildArch:     noarch

%description
Provides OpenShift client libraries

%prep
%setup -q
pwd
rake --trace version["%{version}"]

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
# Ignore dependencies here because these will be handled by rpm 
gem install --install-dir $RPM_BUILD_ROOT/%{gemdir} --bindir $RPM_BUILD_ROOT/%{_bindir} --local -V --force --rdoc --ignore-dependencies \
     pkg/rhc-%{version}.gem

# Copy the bash autocompletion script
mkdir -p "$RPM_BUILD_ROOT/etc/bash_completion.d/"
cp autocomplete/rhc $RPM_BUILD_ROOT/etc/bash_completion.d/rhc

cp LICENSE $RPM_BUILD_ROOT/%{gemdir}/gems/rhc-%{version}/LICENSE
cp COPYRIGHT $RPM_BUILD_ROOT/%{gemdir}/gems/rhc-%{version}/COPYRIGHT

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc doc/USAGE.txt
%doc LICENSE
%doc COPYRIGHT
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
%{_mandir}/man1/rhc*
%{_mandir}/man5/express*
%{gemdir}/gems/rhc-%{version}/
%{gemdir}/cache/rhc-%{version}.gem
%{gemdir}/doc/rhc-%{version}
%{gemdir}/specifications/rhc-%{version}.gemspec
%config(noreplace) %{_sysconfdir}/openshift/express.conf
%attr(0644,-,-) /etc/bash_completion.d/rhc

%changelog
* Fri Jul 13 2012 Adam Miller <admiller@redhat.com> 0.96.2-1
- Merge pull request #97 from fotioslindiakos/BZ836483 (johnp@redhat.com)
- Merge pull request #99 from J5/master (ccoleman@redhat.com)
- some fixes to setup command and checking the spec test (johnp@redhat.com)
- Added tests to ensure a domain exists (fotios@redhat.com)
- Fixed error_for to ensure the sprintf won't fail (fotios@redhat.com)
- Ensuring we don't fail if broker sends nil HTTP response (fotios@redhat.com)

* Wed Jul 11 2012 Adam Miller <admiller@redhat.com> 0.96.1-1
- bump_minor_versions for sprint 15 (admiller@redhat.com)

* Wed Jul 11 2012 Adam Miller <admiller@redhat.com> 0.95.13-1
- [rspec] get to 100%% coverage with new wizard command change
  (johnp@redhat.com)
- add a better help formatter (johnp@redhat.com)
- make wizard run from Commander and setup default command line args
  (johnp@redhat.com)
- Merge pull request #94 from fabianofranz/master (ccoleman@redhat.com)
- Added coverage to File ext (chunks) (contact@fabianofranz.com)
- Moved File chunk extension to core_ext.rb (contact@fabianofranz.com)
- Changed tar.gz file check from client to server side when on Windows
  (contact@fabianofranz.com)
- Added a rescue to handle server errors when attempting to create new scaling
  applications (nhr@redhat.com)
- Removed debug code (contact@fabianofranz.com)
- Merge branch 'master' of github.com:openshift/os-client-tools
  (contact@fabianofranz.com)
- Fixes BZ 836097 (contact@fabianofranz.com)

* Tue Jul 10 2012 Adam Miller <admiller@redhat.com> 0.95.12-1
- Merge pull request #92 from J5/master (ccoleman@redhat.com)
- add Config value as default because it correctly evaluates when called
  (johnp@redhat.com)
- [bug #837189] Normalize on generating ssh keys using the wizard
  (johnp@redhat.com)

* Mon Jul 09 2012 Adam Miller <admiller@redhat.com> 0.95.11-1
- Merge pull request #90 from J5/master (contact@fabianofranz.com)
- [bug #816813] fix it so debug=true in conf works with rhc app
  (johnp@redhat.com)
- [spec] add test for ssh helper (johnp@redhat.com)
- bump the key generation to 2048 bits (johnp@redhat.com)
- [bug #837189] call ssh-add when writing out ssh key (johnp@redhat.com)

* Mon Jul 09 2012 Dan McPherson <dmcphers@redhat.com> 0.95.10-1
- Removed debug comments (contact@fabianofranz.com)
- Fixes BZ 837464 (contact@fabianofranz.com)
- Fixes BZ 837191, not parsing \n on windows anymore (using .lines instead)
  (contact@fabianofranz.com)

* Mon Jul 09 2012 Dan McPherson <dmcphers@redhat.com> 0.95.9-1
- Merge pull request #89 from nhr/BZ836177 (ccoleman@redhat.com)
- Merge pull request #87 from J5/master (ccoleman@redhat.com)
- Fixed BZ836177 -  error message is not clear when using invalid domain name
  in rhc setup wizard (nhr@redhat.com)
- Added rspec coverage for Rhc::Rest::Client (nhr@redhat.com)
- [cucumber] add tests for cartridge creation and stub out other tests
  (johnp@redhat.com)
- [cucumber] Suppress simplecov output for rhc scripts (johnp@redhat.com)
- [cucumber] revert debug comments which were mistakenly checked in
  (johnp@redhat.com)

* Thu Jul 05 2012 Adam Miller <admiller@redhat.com> 0.95.8-1
- Added rsepc testing for Rhc::Rest. Made minor fixes to Rhc::Rest base module.
  (nhr@redhat.com)

* Tue Jul 03 2012 Adam Miller <admiller@redhat.com> 0.95.7-1
- added buildrequires rubygem-cucumber because tests are running at rpm build
  time (admiller@redhat.com)

* Mon Jul 02 2012 Adam Miller <admiller@redhat.com> 0.95.6-1
- add comment to the top of coverage_helper (johnp@redhat.com)
- make coverage helper module more ruby'esk (johnp@redhat.com)
- [rake] make a cucumber_local task that runs on the local bundle
  (johnp@redhat.com)
- [rake] clean up tasks (johnp@redhat.com)
- [rake] add cucumber task and allow specifying RHC_SERVER (johnp@redhat.com)
- [cucumber coverage] use a helper to start simplecov (johnp@redhat.com)
- add simplecov to cucumber tests (johnp@redhat.com)
- [simplecov] Seperated simplecov output for spec tests (nhr@redhat.com)
- Fixes BZ 829833, Yard warnings when gem install rhc (ffranz@redhat.com)

* Wed Jun 27 2012 Adam Miller <admiller@redhat.com> 0.95.5-1
- add thor developer dependency so we can run cucumber tests (johnp@redhat.com)
- fix tito build due to move to root directory (johnp@redhat.com)
- Merge pull request #77 from smarterclayton/add_help_information_to_framework
  (johnp@redhat.com)
- Fixes BZ 834813, error while creating scaled apps on Ruby 1.9+
  (ffranz@redhat.com)
- DateTime on Ruby 1.8.7 can't be converted because of timezones
  (ccoleman@redhat.com)
- Ruby 1.8.7 doesn't support to_time (ccoleman@redhat.com)
- Add simple help info to the framework Improve the spec tests so that they
  pass when an openshift config file already exists Get 100%% coverage of
  helpers in helpers_spec.rb Add a way to create global options cleanly from
  the helper (ccoleman@redhat.com)
- Move everything in express/ into the root (ccoleman@redhat.com)
- Add contributing guidelines (ccoleman@redhat.com)
- Merge pull request #75 from smarterclayton/finish_up_cuc_tests
  (ccoleman@redhat.com)
- Ruby 1.8.7 does not support URI#hostname (ccoleman@redhat.com)
- Integrate cucumber into rake, simplify coverage reporting, allow optional
  execution of coverage during cucumber (ccoleman@redhat.com)
- Fix ActiveSupport override in both Ruby 1.8 and 1.9 (ccoleman@redhat.com)

* Sat Jun 23 2012 Dan McPherson <dmcphers@redhat.com> 0.95.4-1
- Merge pull request #67 from matthicksj/add-cuc-tests (ccoleman@redhat.com)
- Switching cucumber to exit on any failure (mhicks@redhat.com)
- Adding rhc app show test (mhicks@redhat.com)
- Better OpenShift Origin instance support and docs (mhicks@redhat.com)
- No need to exclude these fields anymore (mhicks@redhat.com)
- Refactoring, fixes and additional functionality (mhicks@redhat.com)
- Minor fixes, handling rhc setup and configuration (mhicks@redhat.com)
- Adds end to end cucumber integration tests (mhicks@redhat.com)

* Sat Jun 23 2012 Dan McPherson <dmcphers@redhat.com> 0.95.3-1
- Merge pull request #73 from J5/master (ccoleman@redhat.com)
- [rspec] finish up the odds and ends to get Config to 100%% coverage
  (johnp@redhat.com)
- [rspec] break up Config to make it easier for testsing (johnp@redhat.com)
- [rspec] add RHC::Config tests (johnp@redhat.com)
- [rspec] fix home dir switching code to correctly reload config
  (johnp@redhat.com)
- [rspec] move fakefs bits into spec_helper so other tests can benifit
  (johnp@redhat.com)

* Thu Jun 21 2012 Adam Miller <admiller@redhat.com> 0.95.2-1
- Merge pull request #72 from J5/master (ccoleman@redhat.com)
- [simplecov] simpler coverage fix (johnp@redhat.com)
- Merge pull request #69 from J5/master (ccoleman@redhat.com)
- [simplecov] use the same regex for nocov as simplecov uses (johnp@redhat.com)
- Merge pull request #71 from xiy/master (ccoleman@redhat.com)
- Make line enumeration in rhc-port-forward compatible with both ruby 1.8 and
  1.9. (xiy3x0@gmail.com)
- [simplecov] monkey patch to correctly ignore :nocov: lines (johnp@redhat.com)
- [rspec] make stub methods less generic (johnp@redhat.com)
- [rspec] make sure we our internal ssh fingerprint methods match out fallback
  (johnp@redhat.com)
- [rspec] stub out ssh_keygen_fallback instead of exe_cmd (johnp@redhat.com)
- [rspec] silence output during tests by using highline's "say" instead of
  "puts" (johnp@redhat.com)
- remove debug output (johnp@redhat.com)
- [rspec] 100%% wizard coverage (johnp@redhat.com)
- [rspec] get coverage for ssh-keygen fallback (johnp@redhat.com)
- [rspec] more package kit code path coverage (johnp@redhat.com)
- [rspec] cover has_git? error condition (johnp@redhat.com)
- [rcov] cover the dbus_send_session_method method (johnp@redhat.com)
- [rspec wizard] add windows codepath check (johnp@redhat.com)
- [rspec] mock package kit (johnp@redhat.com)
- [rspec] small changes to get better test coverage (johnp@redhat.com)
- [rspec] add a test that runs through the whole wizard in one go
  (johnp@redhat.com)

* Wed Jun 20 2012 Adam Miller <admiller@redhat.com> 0.95.1-1
- bump_minor_versions for sprint 14 (admiller@redhat.com)
- Removing --noprompt from ARGV after we're done with it since the other
  commands complain about it not being a valid option (fotios@redhat.com)

* Wed Jun 20 2012 Adam Miller <admiller@redhat.com> 0.94.8-1
- Improved style (ffranz@redhat.com)
- Minor message improvements (ffranz@redhat.com)
- Fixed wrong forum URL everywhere (ffranz@redhat.com)
- Fixes BZ 826769 - will not fail app create and will show a message when the
  Windows Winsock bug is detected (ffranz@redhat.com)

* Tue Jun 19 2012 Adam Miller <admiller@redhat.com> 0.94.7-1
- Merge pull request #68 from J5/master (ccoleman@redhat.com)
- [bug 831771] require highline 1.5.1 (johnp@redhat.com)
- Merge pull request #66 from smarterclayton/handle_interrupts_gracefully
  (johnp@redhat.com)
- Bug 825766 - Catch any interrupts that have escaped all command execution
  (ccoleman@redhat.com)
- [bug 826472] namespace isn't in config file, don't update when altering
  namespace (johnp@redhat.com)
- update wizard spec tests (johnp@redhat.com)
- [bug 828324]exit 0 on success for rhc app cartridge list (johnp@redhat.com)

* Tue Jun 19 2012 Adam Miller <admiller@redhat.com> 0.94.6-1
- Fixup RHC requires so that only one module is requiring Rubygems, also ensure
  requires are not circular (ccoleman@redhat.com)

* Mon Jun 18 2012 Adam Miller <admiller@redhat.com> 0.94.5-1
- Merge pull request #65 from J5/master (ccoleman@redhat.com)
- add missing parseconfig.rb (johnp@redhat.com)
- Merge pull request #64 from J5/master (ccoleman@redhat.com)
- vendor parseconfig and remove monkey patches (johnp@redhat.com)
- remove some more unused parseconfig code (johnp@redhat.com)
- remove some stale code that must have crept back in from a merge
  (johnp@redhat.com)
- monkey patch parseconfig to remove deprication warnings (johnp@redhat.com)
- only run wizard if a valid command is issued (johnp@redhat.com)
- Improved SSH checks (fotios@redhat.com)
- Bug 831459 - Use the correct RbConfig version depending on Ruby version
  (ccoleman@redhat.com)

* Fri Jun 15 2012 Adam Miller <admiller@redhat.com> 0.94.4-1
- parseconfig 1.0.2 breaks our config module so specify < 1.0
  (johnp@redhat.com)
- fix traceback when checking for git and it is not installed
  (johnp@redhat.com)
- Do fast check for git (path) before slow check (package_kit)
  (ccoleman@redhat.com)
- Bug 831682 - Remove rake from core dependencies (ccoleman@redhat.com)
- add an accessor to config for default_rhlogin (johnp@redhat.com)
- Provide rubygem-rhc so we don't clash with f17 packages (johnp@redhat.com)
- [fix bug 830260] defaults to previously entered username in setup
  (johnp@redhat.com)

* Fri Jun 08 2012 Adam Miller <admiller@redhat.com> 0.94.3-1
- Merge pull request #61 from J5/master (ccoleman@redhat.com)
- fix traceback when checking for git and it is not installed
  (johnp@redhat.com)
- Bug fixes for 790459 and 808440 (abhgupta@redhat.com)
- change wordage for key read warning (johnp@redhat.com)
- Fix dealing with invalid ssh keys (indicate the key can not be read)
  (johnp@redhat.com)
- use the vendor version of SSHKey (johnp@redhat.com)
- fix typo s/message/display (johnp@redhat.com)
- [fix bug 829858] we don't need to check for a .ssh/config file
  (johnp@redhat.com)
- [fix bug 829903] Don't run setup when --help is specified (johnp@redhat.com)

* Fri Jun 08 2012 Adam Miller <admiller@redhat.com> 0.94.2-1
- fix another merge issue (johnp@redhat.com)
- fix merge issue by adding back Requires: rubygem-test-unit (johnp@redhat.com)
- move sshkey into the vendor module (johnp@redhat.com)
- use FileUtils as it works for all versions of ruby >= 1.8.7
  (johnp@redhat.com)
- Pull sshkey module into the source tree since it is small (johnp@redhat.com)
- Update client spec to require rubygem-test-unit, and relax version
  requirements (ccoleman@redhat.com)
- Off by one bug in simplecov, temporarily reduce percentage by 1 because
  coverage report is 100%% green (ccoleman@redhat.com)
- Allow users with bigdecimal as a system gem to run tests (crack requires
  bigdecimal implicitly) (ccoleman@redhat.com)
- Fix to_a bugs in Ruby 1.9 (behavior change, code was not forward compatible)
  (ccoleman@redhat.com)
- Bug 829764 - Add test-unit 1.2.3 as a firm dependency by the gem
  (ccoleman@redhat.com)

* Fri Jun 01 2012 Adam Miller <admiller@redhat.com> 0.94.1-1
- bumping spec versions (admiller@redhat.com)
- Fixed code coverage (:nocov:) (ffranz@redhat.com)
- fix bug #827582 - Wizard's git check returns a false negitive on RHEL6
  (johnp@redhat.com)

* Thu May 31 2012 Adam Miller <admiller@redhat.com> 0.93.18-1
- 

* Thu May 31 2012 Adam Miller <admiller@redhat.com> 0.93.17-1
- Added a fallback for ssh keys fingerprint handling to the setup wizard
  (related to BZ 824318) (ffranz@redhat.com)
- Merge pull request #53 from J5/master (contact@fabianofranz.com)
- extra space caused line continuation to fail (johnp@redhat.com)
- bug #826788, 826814 - fix wording (johnp@redhat.com)
- Merge pull request #51 from fabianofranz/master (johnp@redhat.com)
- Fixes BZ 824318, workaround for older net/ssh versions (usually Mac platform)
  (ffranz@redhat.com)
- fixes bz 826853 - del old config file to make sure new one gets created
  (johnp@redhat.com)
- make spec tests pass again (johnp@redhat.com)
- add ENV['LIBRA_SERVER'] to config options (johnp@redhat.com)
- bz 822833 - make commands read from correct configs (johnp@redhat.com)
- Totally reverted snapshot create and restore to native when not on windows
  (ffranz@redhat.com)

* Wed May 30 2012 Adam Miller <admiller@redhat.com> 0.93.16-1
- Merge pull request #49 from fabianofranz/master (contact@fabianofranz.com)
- Removed warning on Mac platform (ffranz@redhat.com)
- use SSH::Net to load public ssh fingerprint (johnp@redhat.com)
- Fixes BZ 824741 (ffranz@redhat.com)
- Fixed coverage (ffranz@redhat.com)
- Fixed coverage tests (ffranz@redhat.com)
- Fixes BZ 824312, back to native tar if not on windows (ffranz@redhat.com)

* Tue May 29 2012 Adam Miller <admiller@redhat.com> 0.93.15-1
- 

* Tue May 29 2012 Adam Miller <admiller@redhat.com> 0.93.14-1
- Merge pull request #44 from fabianofranz/master (johnp@redhat.com)
- Explanatory comment (ffranz@redhat.com)
- Fixes BZ 823854 (ffranz@redhat.com)

* Tue May 29 2012 Adam Miller <admiller@redhat.com> 0.93.13-1
- fix cmp typo (s/=/==) (johnp@redhat.com)
- make sure we check for uncaught signals if retcode is nil (johnp@redhat.com)
- remove generation of .ssh/config since we default to id_rsa now
  (johnp@redhat.com)
- add the server option to the rhc manpage (johnp@redhat.com)
- autocomplete rhc server and rhc setup (johnp@redhat.com)
- Removed duplicated code for rhc app tail and rhc-tail-files
  (ffranz@redhat.com)
- Fixed BZ 823448 (ffranz@redhat.com)
- Merge pull request #40 from fabianofranz/master (contact@fabianofranz.com)
- Fixes BZ 823441 (ffranz@redhat.com)

* Fri May 25 2012 Adam Miller <admiller@redhat.com> 0.93.12-1
- Removed vendored libs from coverage reports (ffranz@redhat.com)
- Merge pull request #37 from fabianofranz/master (ccoleman@redhat.com)
- workaround for bug #816338 - no longer get redefine warning
  (johnp@redhat.com)
- Vendored libs reorganized (ffranz@redhat.com)
- Fixes BZ 823853 and 824312 (ffranz@redhat.com)
- catch NotImplementedError which is raised for invalid key types
  (johnp@redhat.com)
- typo fix s/FileUtil/FileUtils (johnp@redhat.com)
- [wizard] some more scoping issues (johnp@redhat.com)
- 30 threads testing tar.gz file reads (ffranz@redhat.com)
- Removed pr-zlib in favour of zliby to solve pr-zlib multithreading bug, added
  more rspec tests (ffranz@redhat.com)

* Thu May 24 2012 Adam Miller <admiller@redhat.com> 0.93.11-1
- Merge pull request #34 from J5/master (ccoleman@redhat.com)
- add rhc setup to help docs (johnp@redhat.com)
- [wizard] fix scoping issue uncovered in tests (johnp@redhat.com)
- [tests] add ssh_key upload stage tests (johnp@redhat.com)
- [tests] implement create ssh key tests (johnp@redhat.com)
- [tests] implement File.chmod as a noop for FakeFS (johnp@redhat.com)
- allow home_dir to be set in the configs so it can be set for tests
  (johnp@redhat.com)
- use FileUtil instead of Dir so it works with FakeFS (johnp@redhat.com)
- [tests] implement the write config stage checks (johnp@redhat.com)
- [tests] stub out some http requests in wizard tests (johnp@redhat.com)
- [tests] use the more reliable terminal IO api (johnp@redhat.com)
- [tests] utilize the new mock terminal IO api (johnp@redhat.com)
- [tests] move libra_server def up (johnp@redhat.com)
- [tests] require fakefs (johnp@redhat.com)
- [tests] make it easier to read and write the mock terminal streams
  (johnp@redhat.com)
- make WizardDriver a mixin and allow it to access the stages array
  (johnp@redhat.com)
- [tests] stub out wizzard tests (johnp@redhat.com)

* Thu May 24 2012 Adam Miller <admiller@redhat.com> 0.93.10-1
- 

* Thu May 24 2012 Adam Miller <admiller@redhat.com> 0.93.9-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (ffranz@redhat.com)
- Fixed a helpers bug (ffranz@redhat.com)

* Wed May 23 2012 Adam Miller <admiller@redhat.com> 0.93.8-1
- Improved coverage (ffranz@redhat.com)

* Wed May 23 2012 Adam Miller <admiller@redhat.com> 0.93.7-1
- Improved rspec syntax (ffranz@redhat.com)
- Removed deprecated herpers, added specific .rb for json and targz helpers,
  json and targz tests (ffranz@redhat.com)
- Merge pull request #29 from J5/master (ccoleman@redhat.com)
- Merge pull request #31 from bdecoste/master (contact@fabianofranz.com)
- US2307 (bdecoste@gmail.com)
- fix (johnp@redhat.com)
- Merge remote-tracking branch 'origin/master' into j5 (johnp@redhat.com)
- [tests] check for section(:bottom => -1) senario (johnp@redhat.com)
- [wizard] test coverage for formatter helpers (johnp@redhat.com)
- Add RHC::Helpers test for environment variables (ccoleman@redhat.com)
- [wizard] add formatting helpers to get rid of \n (johnp@redhat.com)
- [wizard] change git test (johnp@redhat.com)
- [wizard] use File.open do end blocks (johnp@redhat.com)
- [wizard] use @libra_server instead of hardcoding urls (johnp@redhat.com)
- [wizard] output formatting fixes (johnp@redhat.com)
- [wizard] add an application info stage (johnp@redhat.com)
- [wizard] namespace creation stage added (root@dhcp-100-2-224.bos.redhat.com)
- [wizard] fallback if using PackageKit fails (johnp@redhat.com)
- [wizard] add default name for ssh key based on fingerprint (johnp@redhat.com)
- [wizard] reformat output and add better worded prompts (johnp@redhat.com)

* Tue May 22 2012 Adam Miller <admiller@redhat.com> 0.93.6-1
- Implement simple server status command 'rhc server' and helpers to support it
  (ccoleman@redhat.com)

* Tue May 22 2012 Adam Miller <admiller@redhat.com> 0.93.5-1
- Merge pull request #28 from fabianofranz/master (contact@fabianofranz.com)
- Fixed rspec tests (ffranz@redhat.com)

* Tue May 22 2012 Adam Miller <admiller@redhat.com> 0.93.4-1
- Fixes an issue related to leaving a file open when reading snapshot files
  (ffranz@redhat.com)
- Merge remote-tracking branch 'upstream/master' (ffranz@redhat.com)
- Fixed tar and gzip bugs on windows, fixed port forwarding bugs on windows
  (ffranz@redhat.com)
- [wizard] all stages must return true to continue processing
  (johnp@redhat.com)
- [wizard] handle case where the user has no ssh keys, even 'default'
  (johnp@redhat.com)
- [wizard] add ability to rerun by calling rhc setup (johnp@redhat.com)
- [wizard] fix print out of command (johnp@redhat.com)
- [wizard] add windows stage which prints out client tool info
  (johnp@redhat.com)
- [wizard] add the package check and install phase (johnp@redhat.com)

* Fri May 18 2012 Adam Miller <admiller@redhat.com> 0.93.3-1
- [wizard] use highline say and ask for input and output (johnp@redhat.com)

* Thu May 17 2012 Adam Miller <admiller@redhat.com> 0.93.2-1
- [wizard] check if sshkey is uploaded and if not upload it (johnp@redhat.com)
- remove merge artifact (johnp@redhat.com)
- caught some more places to convert to the Config module (johnp@redhat.com)
- Merges Windows bug fixes (ffranz@redhat.com)
- Back to highline for user input, use * echo on password input
  (ffranz@redhat.com)
- Fixes bz 816644 (ffranz@redhat.com)
- get default_proxy from the Config singlton instead of as a magic var
  (johnp@redhat.com)
- break out wizard to its own module (root@dhcp-100-2-224.bos.redhat.com)
- Increased timeout when creating scaled apps (ffranz@redhat.com)
- Fixed port forwarding for scaled apps (bz 816644) (ffranz@redhat.com)
- fixed typo (johnp@redhat.com)
- use new Config module (johnp@redhat.com)
- add new config module (johnp@redhat.com)
- quick fix - add --noprompt switch to bypass first run wizard
  (johnp@redhat.com)
- Temporary commit to build (johnp@redhat.com)
- Remove native extension builds and update the spec with the necessary RPMs
  (ccoleman@redhat.com)
- Newer versions of rspec are loading empty specs (ccoleman@redhat.com)
- Using commander create command infrastructure for registration and a simple
  'status' command With RSpec, ensure 100%% code coverage and make <100%% of
  required code being covered by tests fail build Add an example 'status'
  command that demonstrates registration for simple testing, and add it to
  'rhc' (ccoleman@redhat.com)
- Fixes rhc.gemspec (typo during previous merge) (ffranz@redhat.com)
- Merging windows branch (ffranz@redhat.com)
- Add travis build indicator to express/README.md (ccoleman@redhat.com)
- Exclude Gemfile.lock (ccoleman@redhat.com)
- Use a core gemspec file with the appropriate content Change Rake to default
  to :test over :package Add a simple RHC module Move autocomplete rhc script
  out of lib directory and into autocomplete/ (ccoleman@redhat.com)
- Refactored Rakefile to pull from tasks/*.rake Added more rake test tasks
  (like test:functionals) Added dependencies into Gemfile so Travis will
  install them Added requirement for gem version of test-unit so we can omit
  tests gracefully Added omission code to domain and application tests for now
  Merge changes to remove domain name (fotios@redhat.com)
- Validates the snapshot .tar.gz file locally (ffranz@redhat.com)
- Removed native zlib requirement, added vendored pure Ruby zlib (rbzlib)
  (ffranz@redhat.com)
- Removed highline gem, using our own prompt solution (ffranz@redhat.com)
- Ported rhc app snapshot to pure ruby, unified code with rhc-snapshot
  (ffranz@redhat.com)
- Ported rhc-snapshot to minitar (ffranz@redhat.com)
- Ported tar command to pure ruby using minitar and zlib ruby
  (ffranz@redhat.com)
- Improved error handling and capturing sigint (ffranz@redhat.com)
- Port checking and port forwarding now working with Net::SSH
  (ffranz@redhat.com)
- Forwarding ports through net::ssh (todo: convert list_ports also)
  (ffranz@redhat.com)
- Completely removed json gems in favour of vendored okjson.rb
  (ffranz@redhat.com)
- Added highline dep :( but passwords work properly in windows now
  (mmcgrath@redhat.com)
- removed s.extensions because it caused the gem to get flagged as native this
  causes issues in windows (mmcgrath@redhat.com)
- Added new deps (Mike McGrath)
- replacing libra_id_rsa with standard id_rsa (Mike McGrath)
- remove openssh dep on tail-files and use Net::SSH instead (Mike McGrath)
- Wizard now supports uploading keys (among others, see full commit message)
  (builder@example.com)
- Added initial wizard, still needs work (mmcgrath@redhat.com)
- Startred adding native ruby ssh bindings (mmcgrath@redhat.com)

* Thu May 10 2012 Adam Miller <admiller@redhat.com> 0.93.1-1
- Merge pull request #18 from rmillner/master (ccoleman@redhat.com)
- bumping spec versions (admiller@redhat.com)
- Let the broker dictate what valid gear sizes are for the user.
  (rmillner@redhat.com)

* Wed May 09 2012 Adam Miller <admiller@redhat.com> 0.92.10-1
- Removed large gear size, only small and medium for now (ffranz@redhat.com)

* Tue May 08 2012 Adam Miller <admiller@redhat.com> 0.92.9-1
- Bug 819739 (dmcphers@redhat.com)

* Mon May 07 2012 Adam Miller <admiller@redhat.com> 0.92.8-1
- TA2025 (bdecoste@gmail.com)

* Fri May 04 2012 Dan McPherson <dmcphers@redhat.com> 0.92.7-1
- Revert "Merge pull request #12 from fotioslindiakos/config_file"
  (dmcphers@redhat.com)

* Fri May 04 2012 Adam Miller <admiller@redhat.com> 0.92.6-1
- Fix for BugZ#817985. gear_profile was not being passed for scaled apps
  (kraman@gmail.com)
- Added config file generation (fotios@redhat.com)
- Added tests and renamed REST tests so they don't get executed by rake since
  they rely on a devenv (fotios@redhat.com)
- Fixed checking for debug flag in config file to allow command line to
  override (fotios@redhat.com)

* Thu May 03 2012 Adam Miller <admiller@redhat.com> 0.92.5-1
- 

* Thu May 03 2012 Adam Miller <admiller@redhat.com> 0.92.4-1
- Fix for BugZ#817985. gear_profile was not being passed for scaled apps
  (kraman@gmail.com)

* Tue May 01 2012 Adam Miller <admiller@redhat.com> 0.92.3-1
- Revert "Merge pull request #10 from fotioslindiakos/config_file" - some
  failing tests, will retry.  Be sure to resubmit pull request.
  (ccoleman@redhat.com)
- Merge pull request #10 from fotioslindiakos/config_file
  (smarterclayton@gmail.com)
- remove rhc-rest removal message (dmcphers@redhat.com)
- Renamed REST based tests so they're not run via rake test (fotios@redhat.com)
- Added documentation to the new functions in rhc-common (fotios@redhat.com)
- Added tests for new config files. Also added a pseudo-fixtures file for
  testing and a script to generate that YAML (fotios@redhat.com)
- Broke config file generation down into multiple functions (fotios@redhat.com)
- add rake require and rhc-rest obsolete (dmcphers@redhat.com)
- Improved ~/.openshift/express.conf generation   - allows us to specify a hash
  of config variables, comments, and default values   - checks the users
  current configuration     - preserves modified settings     -
  restores/updates comments (in case we change something)     - adds new
  variables and removes deprecated ones     - saves the user's old config to
  ~/.openshift/express.bak In response to
  https://bugzilla.redhat.com/show_bug.cgi?id=816763 (fotios@redhat.com)
- Improved config file generation for
  https://bugzilla.redhat.com/show_bug.cgi?id=816763 (fotios@redhat.com)

* Fri Apr 27 2012 Adam Miller <admiller@redhat.com> 0.92.2-1
- Fix for Bugz#812308 (kraman@gmail.com)

* Thu Apr 26 2012 Adam Miller <admiller@redhat.com> 0.92.1-1
- bumping spec versions (admiller@redhat.com)

* Wed Apr 25 2012 Adam Miller <admiller@redhat.com> 0.91.10-1
- 

* Wed Apr 25 2012 Adam Miller <admiller@redhat.com> 0.91.9-1
- Removed finding rhc-rest before uninstalling since we can just catch the
  uninstall error. This was causing problems on Ubuntu (fotios@redhat.com)
- Changed JSON library checking for only install json_pure if native json fails
  (fotios@redhat.com)

* Tue Apr 24 2012 Adam Miller <admiller@redhat.com> 0.91.8-1
- Added ability to remove rhc-rest when this gem gets installed This should
  prevent any conflicts between old rhc-rest and new libs/rhc-rest*
  (fotios@redhat.com)
- Added rake as a dependency, so extension building will succeed Added rescue
  around native json installation and fallback to json_pure (fotios@redhat.com)

* Tue Apr 24 2012 Adam Miller <admiller@redhat.com> 0.91.7-1
- update scaling entry to include jenkins-client-1.4 as embedded cartridge
  (davido@redhat.com)

* Mon Apr 23 2012 Adam Miller <admiller@redhat.com> 0.91.6-1
- added --scaling details, fixed some formatting, adding path arg to --config
  (davido@redhat.com)

* Fri Apr 20 2012 Adam Miller <admiller@redhat.com> 0.91.5-1
- exit with exit code 0 is --help is invoked (johnp@redhat.com)
- updated --timeout details, fixed typo, removed 'Express' (davido@redhat.com)

* Thu Apr 19 2012 Adam Miller <admiller@redhat.com> 0.91.4-1
- It was decided that the connect-timeout parameter was extraneous.
  (rmillner@redhat.com)
- Mixed up variable names (rmillner@redhat.com)
- After discussions; it was decided to just have one timeout parameter and a
  connect_timeout config file option which can increase both timeouts from
  their defaults. (rmillner@redhat.com)

* Wed Apr 18 2012 Adam Miller <admiller@redhat.com> 0.91.3-1
- Added logic from fotios to skip gems dep installer steps
  (admiller@redhat.com)
- Ignore gem dep solver, we use rpm for deps (admiller@redhat.com)

* Wed Apr 18 2012 Adam Miller <admiller@redhat.com> 0.91.2-1
- Fixed paths for new combined rhc package (fotios@redhat.com)
- Moved rhc-rest files into express (fotios@redhat.com)
- Make the timeout parameter specific to the session timeout and add a
  connection timeout. (rmillner@redhat.com)
- Following request in bugzilla ticket 813110; further increase the timeout to
  120s. (rmillner@redhat.com)
- The default read timeout is causing build/test failures and user-visible
  bugs.  Increasing the read timeout default to 90s which is 30%% higher than
  our current worst-case non-scalable app creation time. (rmillner@redhat.com)
- Fixing extensions so the build will pass (fotios@redhat.com)
- Update Rakefile with move (ccoleman@redhat.com)
- Merge branch 'master' of github.com:openshift/os-client-tools
  (dmcphers@redhat.com)
- Add links to the getting started guide (ccoleman@redhat.com)
- Update README.md with recent changes. (ccoleman@redhat.com)
- US2145: properly choosing json/json_pure based on installation environment
  (fotios@redhat.com)
- Fixed error output for non-scalable apps (fotios@redhat.com)

* Mon Apr 16 2012 Dan McPherson <dmcphers@redhat.com> 0.91.1-1
- add read timeout (dmcphers@redhat.com)

* Thu Apr 12 2012 Mike McGrath <mmcgrath@redhat.com> 0.90.6-1
- BZ810790: Fixed app scaling payload creation (fotios@redhat.com)

* Wed Apr 11 2012 Mike McGrath <mmcgrath@redhat.com> 0.90.5-1
- Struct::Fakeresponse was not defined in a couple of instances.
  (rmillner@redhat.com)

* Wed Apr 11 2012 Adam Miller <admiller@redhat.com> 0.90.4-1
- error out if archive is not found when restoring a snapshot
  (johnp@redhat.com)

* Wed Apr 11 2012 Adam Miller <admiller@redhat.com> 0.90.3-1
- Merge branch 'master' of https://github.com/openshift/os-client-tools
  (admiller@redhat.com)
- Fixes #807200: added a handler for FakeResponse - error messages related to
  scaling apps (ffranz@redhat.com)

* Tue Apr 10 2012 Adam Miller <admiller@redhat.com> 0.90.2-1
- API change in REST api - use domain.id instead of domain.namespace
  (johnp@redhat.com)
- corrected end_point in rhc client tools (lnader@redhat.com)
- add port-forward to the list of autocomplete verbs for rhc (johnp@redhat.com)
- Renaming gem extension so builder can find it (fotios@redhat.com)
- initialize global $remote_ssh_pubkeys at the very top of first test
  (johnp@redhat.com)
- BZ809335: Added rhc-rest dependency to gemspec and made sure test-unit is
  properly installed in 1.9 (fotios@redhat.com)
- BZ810439: Fixed dependency for client tools to require latest version of rhc-
  rest (fotios@redhat.com)
- if gnutar exists use that (johnp@redhat.com)
- bug fixes (lnader@redhat.com)

* Mon Apr 09 2012 Dan McPherson <dmcphers@redhat.com> 0.90.1-1
- make sure $remote_ssh_pubkeys is an empty list, not nil (johnp@redhat.com)
- Added scaling support to cli tools (fotios@redhat.com)
- bump spec number (dmcphers@redhat.com)

* Mon Apr 02 2012 Mike McGrath <mmcgrath@redhat.com> 0.89.12-1
- create an error response instead of returning false (johnp@redhat.com)

* Sat Mar 31 2012 Dan McPherson <dmcphers@redhat.com> 0.89.11-1
- remove newlines from help text (johnp@redhat.com)
- error out on app create if domain isn't created yet (johnp@redhat.com)

* Fri Mar 30 2012 Dan McPherson <dmcphers@redhat.com> 0.89.10-1
- 

* Thu Mar 29 2012 Dan McPherson <dmcphers@redhat.com> 0.89.9-1
- add Requires dep on rhc-rest (johnp@redhat.com)
- make --info work when there are no domains or multiple domains
  (johnp@redhat.com)
- handle empty domains and multiple domains (johnp@redhat.com)
- Solve undefined method [] error. (rmillner@redhat.com)

* Wed Mar 28 2012 Dan McPherson <dmcphers@redhat.com> 0.89.8-1
- add scaling to rhc-app (rmillner@redhat.com)

* Tue Mar 27 2012 Dan McPherson <dmcphers@redhat.com> 0.89.7-1
- Clean up command help (rmillner@redhat.com)
- Creating scalable apps was causing a timeout.  Needed to setup an exception
  to propagate that back to the end-user. (rmillner@redhat.com)

* Tue Mar 27 2012 Dan McPherson <dmcphers@redhat.com> 0.89.6-1
- 

* Tue Mar 27 2012 Dan McPherson <dmcphers@redhat.com> 0.89.5-1
- 

* Mon Mar 26 2012 Dan McPherson <dmcphers@redhat.com> 0.89.4-1
- 

* Mon Mar 26 2012 Dan McPherson <dmcphers@redhat.com> 0.89.3-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (lnader@redhat.com)
- US1876 (lnader@redhat.com)
- add -g option to rhc-app man page (johnp@redhat.com)
- add rhc-port-forward to the rhc command (rhc port-forward) (johnp@redhat.com)

* Sat Mar 17 2012 Dan McPherson <dmcphers@redhat.com> 0.89.2-1
- 

* Sat Mar 17 2012 Dan McPherson <dmcphers@redhat.com> 0.89.1-1
- bump spec number (dmcphers@redhat.com)
- Changed allowed scalable types (fotios@redhat.com)

* Thu Mar 15 2012 Dan McPherson <dmcphers@redhat.com> 0.88.9-1
- Bug 800742 (dmcphers@redhat.com)

* Wed Mar 14 2012 Dan McPherson <dmcphers@redhat.com> 0.88.8-1
- Merge pull request #7 from jwhonce/master (jwhonce@gmail.com)
- targeting LICENSE and COPYRIGHT (jhonce@redhat.com)

* Wed Mar 14 2012 Dan McPherson <dmcphers@redhat.com> 0.88.7-1
- Merge pull request #6 from jwhonce/master (jwhonce@gmail.com)
- named target files (jhonce@redhat.com)

* Wed Mar 14 2012 Dan McPherson <dmcphers@redhat.com> 0.88.6-1
- Merge pull request #5 from jwhonce/master (jwhonce@gmail.com)
- License and Copyright files targeted for wrong directory (jhonce@redhat.com)

* Wed Mar 14 2012 Dan McPherson <dmcphers@redhat.com> 0.88.5-1
- Updated Copyright and License files (jhonce@redhat.com)
- Add gear-size option. (rmillner@redhat.com)

* Mon Mar 12 2012 Dan McPherson <dmcphers@redhat.com> 0.88.4-1
- Modified flag for scaling (fotios@redhat.com)
- fixing bug 800586 - printing git url in case of -no-git and no-dns option
  (abhgupta@redhat.com)
- The return values from expose and show-port are not being parsed by the API
  and setup behind the scenes as part of scaling.  These commands were exposed
  for testing and aren't needed any more. (rmillner@redhat.com)

* Fri Mar 09 2012 Dan McPherson <dmcphers@redhat.com> 0.88.3-1
- bump api version (dmcphers@redhat.com)

* Thu Mar 08 2012 Dan McPherson <dmcphers@redhat.com> 0.88.2-1
- Change std size to small (rmillner@redhat.com)
- add medium gear size (rmillner@redhat.com)
- Added some new REST API features to app creation (fotios@redhat.com)
- rename raw to diy in the man pages (abhgupta@redhat.com)

* Fri Mar 02 2012 Dan McPherson <dmcphers@redhat.com> 0.88.1-1
- bumping spec version (dmcphers@redhat.com)

* Fri Mar 02 2012 Dan McPherson <dmcphers@redhat.com> 0.87.8-1
- fix case (dmcphers@redhat.com)
- fix for bug 799375 - rhc app show now returns exit code 1 if app does not
  exist (abhgupta@redhat.com)

* Wed Feb 29 2012 Dan McPherson <dmcphers@redhat.com> 0.87.7-1
- fix for bug 798674 - rhc wrapper commands now return the actual exit codes
  (abhgupta@redhat.com)

* Tue Feb 28 2012 Dan McPherson <dmcphers@redhat.com> 0.87.6-1
- Update w/ correct license and export doc (jim@jaguNET.com)

* Sat Feb 25 2012 Dan McPherson <dmcphers@redhat.com> 0.87.5-1
- rename jboss 7.0 to jboss 7 (dmcphers@redhat.com)

* Fri Feb 24 2012 Dan McPherson <dmcphers@redhat.com> 0.87.4-1
- print out error message if invalid gear size is passed (johnp@redhat.com)

* Tue Feb 21 2012 Dan McPherson <dmcphers@redhat.com> 0.87.3-1
- Add show-port call. (rmillner@redhat.com)
- update man page for rhc-create-app to reflect the -g option
  (johnp@redhat.com)
- add a -g option to specify gear size (johnp@redhat.com)

* Mon Feb 20 2012 Dan McPherson <dmcphers@redhat.com> 0.87.2-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- allowing underscores in ssh key names (abhgupta@redhat.com)

* Thu Feb 16 2012 Dan McPherson <dmcphers@redhat.com> 0.87.1-1
- bump spec numbers (dmcphers@redhat.com)
- Bugzilla ticket 768809: The jenkins command line option description breaks up
  the flow too much and line wraps poorly.  Moved to a note below the argument
  description. (rmillner@redhat.com)

* Wed Feb 15 2012 Dan McPherson <dmcphers@redhat.com> 0.86.7-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- fix for bug 790987 (abhgupta@redhat.com)

* Wed Feb 15 2012 Dan McPherson <dmcphers@redhat.com> 0.86.6-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- fix for bug 790795 (abhgupta@redhat.com)
- Merge branch 'patch-1' of https://github.com/Qalthos/os-client-tools
  (abhgupta@redhat.com)
- Fixed some SSH key issues and improved error message specification
  (fotios@redhat.com)
- Fix for BZ786230 when account doesn't exist (fotios@redhat.com)
- Tell tar to use the wildcard instead of looking for a folder called '*'.
  (Qalthos@gmail.com)

* Mon Feb 13 2012 Dan McPherson <dmcphers@redhat.com> 0.86.5-1
- Rolling back my changes to expose targetted proxy. Revert "Add '--target'
  option for expose/conceal port options." (rmillner@redhat.com)
- Rolling back my changes to expose targetted proxy. Revert "The target option
  was intended to be optional." (rmillner@redhat.com)

* Mon Feb 13 2012 Dan McPherson <dmcphers@redhat.com> 0.86.4-1
- fix for bug 789928 (abhgupta@redhat.com)
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- fix for bug 789928 (abhgupta@redhat.com)
- Merge branch 'master' of github.com:openshift/os-client-tools
  (mmcgrath@redhat.com)
- return the json rep so it can be used (mmcgrath@redhat.com)

* Mon Feb 13 2012 Dan McPherson <dmcphers@redhat.com> 0.86.3-1
- The target option was intended to be optional. (rmillner@redhat.com)
- Add '--target' option for expose/conceal port options. (rmillner@redhat.com)
- bug 722828 (bdecoste@gmail.com)

* Wed Feb 08 2012 Dan McPherson <dmcphers@redhat.com> 0.86.2-1
- Adding expose / conceal ports (mmcgrath@redhat.com)
- remove use of broker_version (dmcphers@redhat.com)

* Fri Feb 03 2012 Dan McPherson <dmcphers@redhat.com> 0.86.1-1
- bump spec numbers and remove combo (dmcphers@redhat.com)

* Fri Feb 03 2012 Dan McPherson <dmcphers@redhat.com> 0.85.12-1
- fix for bug 787120 (abhgupta@redhat.com)

* Wed Feb 01 2012 Dan McPherson <dmcphers@redhat.com> 0.85.11-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- fix for bug 786339 - added option -t in the rhc-app man page
  (abhgupta@redhat.com)
- Fix for BZ 690465 - Merge changes originally made by jhonce
  (aboone@redhat.com)
- rhc-create-app man page: wsgi -> python and rack -> ruby (BZ 786356)
  (aboone@redhat.com)

* Tue Jan 31 2012 Dan McPherson <dmcphers@redhat.com> 0.85.10-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- fix for bug 785948 - defaulting to bash auto completion if the rhc auto
  completion does not find any matches (abhgupta@redhat.com)

* Mon Jan 30 2012 Dan McPherson <dmcphers@redhat.com> 0.85.9-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (dmcphers@redhat.com)
- modification to the usage description (abhgupta@redhat.com)

* Mon Jan 30 2012 Dan McPherson <dmcphers@redhat.com> 0.85.8-1
- exiting with 1 instead of 0 in case rhc-domain-info returns an exit code
  other than 0 (abhgupta@redhat.com)
- fix for bug 785647 (abhgupta@redhat.com)
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- fix for bug 785638 (abhgupta@redhat.com)

* Sun Jan 29 2012 Dan McPherson <dmcphers@redhat.com> 0.85.7-1
- 

* Sun Jan 29 2012 Dan McPherson <dmcphers@redhat.com> 0.85.6-1
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- added man files for the new rhc wrapper commands (abhgupta@redhat.com)

* Fri Jan 27 2012 Dan McPherson <dmcphers@redhat.com> 0.85.5-1
- removing the check for bash completion directory in the spec file
  (abhgupta@redhat.com)
- added man file for top level rhc command (abhgupta@redhat.com)
- corrected the command description in the usage text (abhgupta@redhat.com)

* Fri Jan 27 2012 Dan McPherson <dmcphers@redhat.com> 0.85.4-1
- 

* Fri Jan 27 2012 Dan McPherson <dmcphers@redhat.com> 0.85.3-1
- minor fixe to rhc domain status command (abhgupta@redhat.com)
- fixing self identified bugs as well as those identified by Dan
  (abhgupta@redhat.com)
- changes required due to ssh_key response structure change
  (abhgupta@redhat.com)
- changing message content to reflect new commands (abhgupta@redhat.com)
- more fixes to the new wrapper commands (abhgupta@redhat.com)
- fixing issues identified during self testing (abhgupta@redhat.com)
- fixes to rhc rpm spec file (abhgupta@redhat.com)
- rolling back change to convert application and namespace name to lowercase
  (abhgupta@redhat.com)
- converting application and namespace names to lowercase before passing to the
  server (abhgupta@redhat.com)
- correction in rhc app command usage description (abhgupta@redhat.com)
- minor correction to auto completion bash script (abhgupta@redhat.com)
- added bash completion script and other minor changes (abhgupta@redhat.com)
- using rhc-domain-info consistently (abhgupta@redhat.com)
- Merge branch 'master' of github.com:openshift/os-client-tools
  (abhgupta@redhat.com)
- new rhc command structure implemented (abhgupta@redhat.com)

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
