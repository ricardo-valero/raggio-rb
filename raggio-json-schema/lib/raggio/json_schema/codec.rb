# frozen_string_literal: true

require "raggio-schema"
require_relative "schema"

module Raggio
  module JsonSchema
    # Codec that transforms Raggio Schema AST ↔ JSON Schema
    class Codec < Raggio::Schema::Base
      transform(
        Raggio::Schema::AST,
        Schema,
        decode: ->(ast) { ast_to_json_schema(ast) },
        encode: ->(json_schema) { json_schema_to_ast(json_schema) }
      )

      def self.ast_to_json_schema(ast)
        case ast[:_type]
        when "string"
          result = {type: "string"}
          result[:minLength] = ast[:constraints][:min] if ast[:constraints][:min]
          result[:maxLength] = ast[:constraints][:max] if ast[:constraints][:max]
          result[:pattern] = ast[:constraints][:format] if ast[:constraints][:format]
          result
        when "number"
          result = {type: "number"}
          result[:minimum] = ast[:constraints][:min] if ast[:constraints][:min]
          result[:maximum] = ast[:constraints][:max] if ast[:constraints][:max]
          result[:exclusiveMinimum] = ast[:constraints][:greater_than] if ast[:constraints][:greater_than]
          result[:exclusiveMaximum] = ast[:constraints][:less_than] if ast[:constraints][:less_than]
          result
        when "integer"
          result = {type: "integer"}
          result[:minimum] = ast[:constraints][:min] if ast[:constraints][:min]
          result[:maximum] = ast[:constraints][:max] if ast[:constraints][:max]
          result[:exclusiveMinimum] = ast[:constraints][:greater_than] if ast[:constraints][:greater_than]
          result[:exclusiveMaximum] = ast[:constraints][:less_than] if ast[:constraints][:less_than]
          result
        when "boolean"
          {type: "boolean"}
        when "null"
          {type: "null"}
        when "symbol"
          {type: "string"}
        when "literal"
          if ast[:values].length == 1
            {const: ast[:values].first}
          else
            {enum: ast[:values]}
          end
        when "array"
          result = {type: "array"}
          result[:items] = ast_to_json_schema(ast[:item_type])
          result[:minItems] = ast[:constraints][:min] if ast[:constraints][:min]
          result[:maxItems] = ast[:constraints][:max] if ast[:constraints][:max]
          result
        when "tuple"
          {
            type: "array",
            prefixItems: ast[:elements].map { |el| ast_to_json_schema(el) },
            minItems: ast[:elements].length,
            maxItems: ast[:elements].length
          }
        when "struct"
          result = {type: "object"}
          properties = {}
          ast[:fields].each do |key, field_ast|
            properties[key] = ast_to_json_schema(field_ast)
          end
          result[:properties] = properties unless properties.empty?
          result[:required] = ast[:required] unless ast[:required].empty?
          result[:additionalProperties] = false
          result
        when "record"
          {
            type: "object",
            additionalProperties: ast_to_json_schema(ast[:value_type])
          }
        when "union"
          converted_members = ast[:members].map { |member| ast_to_json_schema(member) }
          if converted_members.length == 2 && converted_members.any? { |m| m == {type: "null"} }
            non_null = converted_members.find { |m| m != {type: "null"} }
            return non_null.merge({type: [non_null[:type], "null"]}) if non_null[:type]
          end
          {anyOf: converted_members}
        when "discriminated_union"
          {
            oneOf: ast[:variants].values.map { |variant| ast_to_json_schema(variant) }
          }
        when "optional"
          result = ast_to_json_schema(ast[:inner_type])
          result[:default] = ast[:default_value] if ast[:default_value]
          result
        when "lazy"
          ast_to_json_schema(ast[:inner_type])
        else
          raise "Unsupported AST type: #{ast[:_type]}"
        end
      end

      def self.json_schema_to_ast(json_schema)
        # TODO: Implement reverse transformation
        raise NotImplementedError, "JSON Schema → Raggio AST not yet implemented"
      end
    end
  end
end
