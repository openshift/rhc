#!/usr/bin/env ruby

require 'rubygems'
require 'rake'
require 'rake/testtask'

desc 'Runs test:units, test:functionals, test:integration together'
task :test do
  errors = %w(test:units test:functionals test:integration).collect do |task|
    begin
      Rake::Task[task].invoke
      nil
    rescue => e
      task
    end
  end.compact
  abort "Errors running #{errors * ', '}!" if errors.any?
end

namespace :test do
  desc "Run unit tests"
  Rake::TestTask.new(:units) do |t|
    t.libs << "test"
    t.pattern = 'test/unit/**/*_test.rb'
  end

  desc "Run functional tests"
  Rake::TestTask.new(:functionals) do |t|
    t.libs << "test"
    t.pattern = 'test/functional/**/*_test.rb'
  end

  desc "Run integration tests"
  Rake::TestTask.new(:integration) do |t|
    t.libs << "test"
    t.pattern = 'test/integration/**/*_test.rb'
  end

  desc "Run benchmark tests"
  Rake::TestTask.new(:benchmark) do |t|
    t.libs << 'test'
    t.pattern = 'test/performance/**/*_test.rb'
    t.options = '-- --benchmark'
  end

  desc "Run profile tests"
  Rake::TestTask.new(:profile) do |t|
    t.libs << 'test'
    t.pattern = 'test/performance/**/*_test.rb'
  end
end
