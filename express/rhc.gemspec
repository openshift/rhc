# -*- encoding: utf-8 -*-
require 'rubygems'
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
    s.name = %q{rhc}
    s.version = /(Version: )(.*)/.match(File.read("client.spec"))[2]
    s.author = "Red Hat"
    s.email = %q{openshift@redhat.com}
    s.summary = %q{OpenShift Express Client Tools}
    s.homepage = %q{https://openshift.redhat.com/}
    s.description = %q{The client tools for the OpenShift platform that allow for application management.}
    s.files = FileList['lib/**/*.rb', 'lib/rhc', 'bin/*', 'conf/*'].to_a
    s.files += %w(LICENSE COPYRIGHT README.md Rakefile)
    s.executables = ['rhc', 'rhc-domain', 'rhc-app', 'rhc-sshkey', 'rhc-chk', 'rhc-create-app', 'rhc-create-domain', 'rhc-ctl-domain', 'rhc-ctl-app', 'rhc-snapshot', 'rhc-domain-info', 'rhc-user-info', 'rhc-tail-files', 'rhc-port-forward']
    s.add_dependency('parseconfig')
    s.add_dependency("rest-client")
    # This does not need to be added as a dep for the RPM since it is only needed in extension installation
    s.add_dependency('rake')
    s.add_dependency('sshkey')
    s.add_dependency('net-ssh')
    s.add_dependency('archive-tar-minitar')

    # Leave this message for a few versions, or until we can 
    #   figure out how to get it only displayed if rhc-rest 
    #   is installed (taken care of in extension)
    s.post_install_message = <<-MSG
      ===================================================
        rhc-rest is no longer needed as an external gem
          - If it is installed, it will be removed
          - Its libraries are now included in rhc
            - Any applications requiring rhc-rest will 
              still function as expected
      ===================================================
    MSG
end
