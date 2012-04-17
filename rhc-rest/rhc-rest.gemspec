# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rhc-rest/version"
bin_dir  = File.join("bin", "*")
lib_dir  = File.join(File.join("lib", "**"), "*")
doc_dir  = File.join(File.join("doc", "**"), "*")

Gem::Specification.new do |s|
  s.name        = "rhc-rest"
  s.version     = /(Version: )(.*)/.match(File.read("rhc-rest.spec"))[2].strip
  s.authors     = ["Red Hat"]
  s.email       = ["openshift@redhat.com"]
  s.homepage    = "http://www.openshift.com"
  s.summary     = %q{Ruby REST client for OpenShift REST API}
  s.description = %q{Ruby bindings for OpenShift REST API}

  s.rubyforge_project = "rhc-rest"

  s.files         = Dir[lib_dir] + Dir[bin_dir] + Dir[doc_dir]
  s.files         += %w(Rakefile rhc-rest.gemspec Gemfile rhc-rest.spec COPYRIGHT LICENSE)
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # TODO: This breaks the build, need to figure out a way around it
  #s.extensions << 'ext/mkrf_conf.rb'
  s.add_dependency("json")

  s.add_dependency("rest-client")
end
