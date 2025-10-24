# frozen_string_literal: true

require "bundler"
require "rspec/core/rake_task"

GEMS = %w[raggio raggio-schema raggio-json-schema].freeze

def for_each_gem(&block)
  GEMS.each do |gem|
    Dir.chdir(gem) do
      puts "\n=== #{gem} ==="
      block.call(gem)
    end
  end
end

desc 'Execute a command in each gem (usage: rake each CMD="bundle exec rspec")'
task :each do
  cmd = ENV.fetch("CMD", nil)
  raise "Please provide CMD environment variable" unless cmd

  for_each_gem do |_gem|
    sh cmd
  end
end

desc "Run rspec for all gems"
task :rspec do
  for_each_gem do |_gem|
    Bundler.with_unbundled_env { sh "bundle exec rspec" }
  end
end

desc "Build all gems"
task :build do
  for_each_gem do |_gem|
    sh "gem build *.gemspec"
  end
end

desc "Install all gems locally"
task install: :build do
  for_each_gem do |_gem|
    gem_file = Dir["*.gem"].first
    sh "gem install #{gem_file}"
  end
end

desc "Clean built gems"
task :clean do
  for_each_gem do |_gem|
    FileUtils.rm(Dir["*.gem"]) if Dir["*.gem"].any?
  end
end

desc "Run standardrb for all gems"
task :standardrb do
  for_each_gem do |_gem|
    Bundler.with_unbundled_env { sh "bundle exec standardrb --fix" }
  end
end

desc "Run tests and linter"
task both: [:rspec, :standardrb]

task default: :both
