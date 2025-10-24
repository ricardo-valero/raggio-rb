# frozen_string_literal: true

require_relative "lib/raggio/json_schema/version"

Gem::Specification.new do |spec|
  spec.name = "raggio-json-schema"
  spec.version = Raggio::JsonSchema::VERSION
  spec.authors = ["Ricardo Valero"]
  spec.email = ["ricardo@valero.dev"]

  spec.summary = "JSON Schema generation for Raggio Schema"
  spec.description = "Generate JSON Schema documents from Raggio Schema definitions"
  spec.homepage = "https://github.com/ricardovalero/raggio-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.add_dependency "raggio-schema"
end
