require 'rubygems'
require 'rake'

Gem::Specification.new do |s|
  s.name = %q{openshift}
  s.version = "0.60.1"
  s.date = %q{2011-07-29}
  s.authors = ["Mike McGrath", "Krishna Raman", "Jim Jagielski"]
  s.email = ["mmcgrath@redhat.com", "kraman@redhat.com", "jimjag@redhat.com"]
  s.summary = %q{Client tools for Redhat Openshift clouds}
  s.homepage = %q{http://www.openshift.com/}
  s.description = %q{Client tools for Redhat Openshift Flex clouds}
  s.files = FileList['lib/**/*.rb', 'bin/*', 'conf/*', '[A-Z]*'].to_a
  s.executables = [
					'os',
					'os-add-cartridge',
					'os-clone-application',
					'os-create-application',
					'os-create-environment',
					'os-delete-application',
					'os-delete-environment',
					'os-deregister-cloud',
					'os-help',
					'os-inspect-application',
					'os-list-applications',
					'os-list-cartridges',
					'os-list-clouds',
					'os-list-environments',
					'os-list-servers',
					'os-open-console',
					'os-register-cloud',
					'os-remove-cartridge',
					'os-restart-application',
					'os-start-application',
					'os-start-environment',
					'os-stop-application',
					'os-stop-environment',
					'os-tail-logs'
				  ]
  s.default_executable = 'bin/os'
  s.add_dependency("json_pure",   ">= 1.4.4", "< 1.5.1")
  s.add_dependency("parseconfig", "~> 0.5.2")
  s.add_dependency("multipart-post", "~> 1.1.2")
  s.add_dependency("highline", "~> 1.6.2")
  s.required_ruby_version = '>= 1.8.7'
  s.requirements << 'git v1.7.4 or greater'
end
