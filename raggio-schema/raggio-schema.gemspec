# frozen_string_literal: true

require_relative "lib/raggio/schema/version"

Gem::Specification.new do |spec|
  spec.name = "raggio-schema"
  spec.version = Raggio::Schema::VERSION
  spec.authors = ["Ricardo Valero"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Schema functionality for Raggio"
  spec.description = "Raggio Schema provides schema validation and utilities"
  spec.homepage = "https://github.com/ricardovalero/raggio-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/raggio-schema/CHANGELOG.md"

  spec.files = Dir.glob("lib/**/*") + %w[README.md CHANGELOG.md]
  spec.require_paths = ["lib"]
end
