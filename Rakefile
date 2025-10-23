require 'bundler'
require 'rspec/core/rake_task'

GEMS = %w[raggio raggio-schema]

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
  cmd = ENV['CMD']
  raise 'Please provide CMD environment variable' unless cmd
  for_each_gem do |gem|
    sh cmd
  end
end

desc 'Run rspec for all gems'
task :rspec do
  for_each_gem do |gem|
    Bundler.with_unbundled_env { sh 'bundle exec rspec' }
  end
end

desc 'Build all gems'
task :build do
  for_each_gem do |gem|
    sh 'gem build *.gemspec'
  end
end

desc 'Install all gems locally'
task install: :build do
  for_each_gem do |gem|
    gem_file = Dir['*.gem'].first
    sh "gem install #{gem_file}"
  end
end

desc 'Clean built gems'
task :clean do
  for_each_gem do |gem|
    FileUtils.rm(Dir['*.gem']) if Dir['*.gem'].any?
  end
end

desc 'Run rubocop for all gems'
task :rubocop do
  for_each_gem do |gem|
    Bundler.with_unbundled_env { sh 'bundle exec rubocop' }
  end
end
