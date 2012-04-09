%global ruby_sitelib %(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")
%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%global gemname rhc-rest
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}


Summary:       Ruby bindings/client for OpenShift REST API
Name:          rhc-rest
Version:       0.0.9
Release:       1%{?dist}
Group:         Network/Daemons
License:       ASL 2.0
URL:           http://openshift.redhat.com
Source0:       rhc-rest-%{version}.tar.gz

BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildRequires: rubygem-rake
BuildRequires: rubygem-rspec
Requires:      ruby >= 1.8.5
Requires:      rubygem-rest-client
Requires:      rubygem-json

BuildArch:     noarch

%description
Provides Ruby bindings/client for OpenShift REST API

%prep
%setup -q

%build
for f in lib/*.rb
do
  ruby -c $f
done

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{gemdir}
mkdir -p %{buildroot}%{ruby_sitelib}

# Build and install into the rubygem structure
gem build %{gemname}.gemspec
gem install --local --install-dir %{buildroot}/%{gemdir} --force %{gemname}-%{version}.gem

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%{gemdir}/gems/rhc-rest-%{version}/
%{gemdir}/cache/rhc-rest-%{version}.gem
%{gemdir}/doc/rhc-rest-%{version}
%{gemdir}/specifications/rhc-rest-%{version}.gemspec
%doc LICENSE
%doc COPYRIGHT

%changelog
* Mon Apr 09 2012 Lili Nader <lnader@redhat.com> 0.0.9-1
- absolute URLs (lnader@redhat.com)
- Made sure debugging output was only printed when @mydebug was specified
  (fotios@redhat.com)
- Ruby REST api changes:  - Make 'domain namespace' consistent across
  domain/app objects. It will be referred as 'id' in domain objects and
  'domain_id' in app objects. (rpenta@redhat.com)
- update sample script for ruby REST api (rpenta@redhat.com)

* Fri Mar 30 2012 Lili Nader <lnader@redhat.com> 0.0.8-1
- Catch all to prevent trying to parse a null response on an http code we did
  not expect. (rmillner@redhat.com)
- Increase the timeout to 3 minutes on creating a scalable application.
  (rmillner@redhat.com)
- Creating scalable apps was causing a timeout.  Needed to setup an exception
  to propagate that back to the end-user. (rmillner@redhat.com)

* Wed Mar 21 2012 Lili Nader <lnader@redhat.com> 0.0.7-1
- Get rhc-rest a building ... (ramr@redhat.com)
- Fix to get rhc-rest building. (ramr@redhat.com)

* Tue Mar 20 2012 Lili Nader <lnader@redhat.com> 0.0.5-1
- corrected version in gemspec (lnader@redhat.com)

* Tue Mar 20 2012 Lili Nader <lnader@redhat.com> 0.0.4-1
- corrected build error (lnader@redhat.com)

* Fri Mar 16 2012 Lili Nader <lnader@redhat.com> 0.0.3-1
- new package built with tito

* Tue Feb 14 2012 Lili Nader <lnader@redhat.com> 0.0.2-1
- new package built with tito






