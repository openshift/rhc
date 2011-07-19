require 'rubygems'
require 'rake'

Gem::Specification.new do |s|
  s.name = %q{rhc}
  s.version = "1.0.0"
  s.date = %q{2011-07-04}
  s.authors = ["Mike McGrath", "Krishna Raman", "Jim Jagielski"]
  s.email = ["mmcgrath@redhat.com", "kraman@redhat.com", "jimjag@redhat.com"]
  s.summary = %q{Client tools for Redhat Openshift clouds}
  s.homepage = %q{http://www.openshit.com/}
  s.description = %q{Client tools for Redhat Openshift Express and Openshift Flex clouds}
  s.files = FileList['lib/**/*.rb', 'bin/*', 'conf/*', '[A-Z]*'].to_a
  s.executables = [
					'rhc',
					'rhc-add-cartridge',
					'rhc-clone-application',
					'rhc-create-application',
					'rhc-create-environment',
					'rhc-delete-application',
					'rhc-delete-environment',
					'rhc-deregister-cloud',
					'rhc-help',
					'rhc-inspect-application',
					'rhc-list-applications',
					'rhc-list-cartridges',
					'rhc-list-clouds',
					'rhc-list-environments',
					'rhc-list-servers',
					'rhc-open-console',
					'rhc-register-cloud',
					'rhc-remove-cartridge',
					'rhc-restart-application',
					'rhc-start-application',
					'rhc-start-environment',
					'rhc-stop-application',
					'rhc-stop-environment'
				  ]
  s.default_executable = 'bin/rhc'
  s.add_dependency("json_pure",   ">= 1.4.4", "< 1.5.1")
  s.add_dependency("parseconfig", "~> 0.5.2")
  s.add_dependency("multipart-post", "~> 1.1.2")
  s.add_dependency("highline", "~> 1.6.2")
  s.required_ruby_version = '>= 1.8.7'
  s.requirements << 'git v1.7.4 or greater'
end
