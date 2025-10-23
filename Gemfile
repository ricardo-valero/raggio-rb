source "https://rubygems.org"

%w[raggio raggio-schema].each do |lib|
  gem lib, :path => File.expand_path("../#{lib}", __FILE__)
end

group :development, :test do
  gem 'rspec', '~> 3.0'
  gem 'rake', '>= 13.0.0'
  gem 'rubocop', '~> 1.80' if RUBY_VERSION >= '3.0'
end

eval File.read('Gemfile-custom') if File.exist?('Gemfile-custom')
