# frozen_string_literal: true

require "raggio-schema"
require_relative "raggio/json_schema/version"
require_relative "raggio/json_schema/schema"
require_relative "raggio/json_schema/codec"

module Raggio
  module JsonSchema
    def self.generate(schema_class, **options)
      # Extract the schema type
      schema_type = (schema_class.is_a?(Class) && schema_class < Raggio::Schema::Base) ?
        schema_class.schema_type :
        schema_class

      # Convert Type instance → AST hash
      ast = Raggio::Schema::Introspection.type_to_ast(schema_type)

      # Validate the AST
      validated_ast = Raggio::Schema::AST.decode(ast)

      # Transform AST → JSON Schema using the codec
      json_schema = Codec.ast_to_json_schema(validated_ast)

      # Add metadata
      json_schema[:$schema] = "https://json-schema.org/draft/2020-12/schema" if options[:id]
      json_schema[:$id] = options[:id] if options[:id]
      json_schema[:title] = options[:title] if options[:title]
      json_schema[:description] = options[:description] if options[:description]

      # Return the JSON Schema (don't validate with metadata - too complex for now)
      json_schema
    end
  end
end
