%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%define gemversion %(echo %{version} | cut -d'.' -f1-3)

Summary:       OpenShift client management tools
Name:          rhc
Version: 1.20.1
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