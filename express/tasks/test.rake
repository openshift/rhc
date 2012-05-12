require "spec/rake/spectask"

desc "Run specs"
Spec::Rake::SpecTask.new do |t|
  t.verbose = false
  t.spec_opts = ['--color']
end

task :default => :spec
