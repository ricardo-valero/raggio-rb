# frozen_string_literal: true

source "https://rubygems.org"

%w[raggio raggio-schema].each do |lib|
  gem lib, path: File.expand_path("../#{lib}", __FILE__)
end

group :development, :test do
  gem "rake", ">= 13.0.0"
  gem "rspec", "~> 3.0"
  gem "standard", "~> 1.0" if RUBY_VERSION >= "3.0"
end

eval File.read("Gemfile-custom") if File.exist?("Gemfile-custom")
