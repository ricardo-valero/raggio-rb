# frozen_string_literal: true

require_relative "lib/raggio/version"

Gem::Specification.new do |spec|
  spec.name = "raggio"
  spec.version = Raggio::VERSION
  spec.authors = ["Ricardo Valero"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Core functionality for Raggio"
  spec.description = "Raggio provides core utilities and functionality"
  spec.homepage = "https://github.com/ricardovalero/raggio-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/raggio/CHANGELOG.md"

  spec.files = Dir.glob("lib/**/*") + %w[README.md CHANGELOG.md]
  spec.require_paths = ["lib"]
end
