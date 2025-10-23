require 'bundler'
require 'rspec/core/rake_task'

GEMS = %w[raggio raggio-schema]

desc 'Run specs for all gems'
task :spec do
  GEMS.each do |gem|
    Dir.chdir(gem) do
      puts "\n=== Running specs for #{gem} ==="
      Bundler.with_unbundled_env do
        sh 'bundle exec rspec'
      end
    end
  end
end

desc 'Build all gems'
task :build do
  GEMS.each do |gem|
    Dir.chdir(gem) do
      puts "\n=== Building #{gem} ==="
      sh 'gem build *.gemspec'
    end
  end
end

desc 'Install all gems locally'
task install: :build do
  GEMS.each do |gem|
    Dir.chdir(gem) do
      puts "\n=== Installing #{gem} ==="
      gem_file = Dir['*.gem'].first
      sh "gem install #{gem_file}"
    end
  end
end

desc 'Clean built gems'
task :clean do
  GEMS.each do |gem|
    Dir.chdir(gem) do
      FileUtils.rm(Dir['*.gem'])
    end
  end
end

desc 'Run rubocop for all gems'
task :rubocop do
  sh 'bundle exec rubocop'
end

task default: :spec
