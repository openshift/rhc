# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rhc-rest/version"

Gem::Specification.new do |s|
  s.name        = "rhc-rest"
  s.version     = Rhc::Rest::VERSION
  s.authors     = ["Red Hat"]
  s.license     = "ASL 2.0"
  s.email       = ["openshift@redhat.com"]
  s.homepage    = "http://www.openshift.com"
  s.summary     = %q{Ruby REST client for OpenShift REST API}
  s.description = %q{Ruby bindings for OpenShift REST API}

  s.rubyforge_project = "rhc-rest"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_runtime_dependency "json"
  s.add_runtime_dependency "rest-client"
end
