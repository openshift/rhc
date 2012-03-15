%define gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)

Summary:       Ruby bindings/client for OpenShift REST API
Name:          rhc-rest
Version:       0.0.2
Release:       1%{?dist}
Group:         Network/Daemons
License:       ASL 2.0
URL:           http://openshift.redhat.com
Source0:       rhc-rest-%{version}.tar.gz

BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildRequires: rubygem-rake
BuildRequires: rubygem-rspec
Requires:      ruby >= 1.8.5
Requires:      rest-client
Requires:      rubygem-json

Requires:      git

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
pwd
rm -rf $RPM_BUILD_ROOT

# Package the gem
rake --trace package

mkdir -p .%{gemdir}
gem install --install-dir $RPM_BUILD_ROOT/%{gemdir} --bindir $RPM_BUILD_ROOT/%{_bindir} --local -V --force --rdoc \
     pkg/rhc-rest-%{version}.gem

cp LICENSE %{gemdir}
cp COPYRIGHT %{gemdir}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc doc/USAGE.txt
%doc LICENSE
%doc COPYRIGHT
%{gemdir}/gems/rhc-rest-%{version}/
%{gemdir}/cache/rhc-rest-%{version}.gem
%{gemdir}/doc/rhc-rest-%{version}
%{gemdir}/specifications/rhc-rest-%{version}.gemspec

%changelog
* Tue Feb 14 2012 Lili Nader <lnader@redhat.com> 0.0.2-1
- new package built with tito






