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
        # Handle discriminated union (oneOf)
        if json_schema[:oneOf]
          variants = {}
          json_schema[:oneOf].each_with_index do |variant, idx|
            # Try to extract discriminator value from variant
            if variant[:properties]
              # Find the discriminator field (assume first const field)
              discriminator_field = variant[:properties].find { |_k, v| v[:const] }
              if discriminator_field
                key = discriminator_field[1][:const]
                variants[key] = json_schema_to_ast(variant)
              else
                variants["variant_#{idx}"] = json_schema_to_ast(variant)
              end
            end
          end
          return {
            _type: "discriminated_union",
            discriminator: "type", # Default discriminator
            variants: variants
          }
        end

        # Handle union (anyOf)
        if json_schema[:anyOf]
          return {
            _type: "union",
            members: json_schema[:anyOf].map { |member| json_schema_to_ast(member) }
          }
        end

        # Handle const
        if json_schema[:const]
          return {
            _type: "literal",
            values: [json_schema[:const]]
          }
        end

        # Handle enum
        if json_schema[:enum]
          return {
            _type: "literal",
            values: json_schema[:enum]
          }
        end

        # Handle $ref
        if json_schema[:$ref]
          # For now, we'll return a placeholder - full $ref resolution would need context
          raise NotImplementedError, "$ref resolution not yet implemented"
        end

        # Handle typed schemas
        type = json_schema[:type]

        # Handle nullable (type array like ["string", "null"])
        if type.is_a?(Array)
          non_null_type = type.find { |t| t != "null" }
          if non_null_type && type.include?("null")
            inner_ast = json_schema_to_ast(json_schema.merge(type: non_null_type))
            return {
              _type: "union",
              members: [inner_ast, {_type: "null"}]
            }
          end
        end

        case type
        when "string"
          constraints = {}
          constraints[:min] = json_schema[:minLength] if json_schema[:minLength]
          constraints[:max] = json_schema[:maxLength] if json_schema[:maxLength]
          constraints[:format] = json_schema[:pattern] if json_schema[:pattern]
          {_type: "string", constraints: constraints}

        when "number"
          constraints = {}
          constraints[:min] = json_schema[:minimum] if json_schema[:minimum]
          constraints[:max] = json_schema[:maximum] if json_schema[:maximum]
          constraints[:greater_than] = json_schema[:exclusiveMinimum] if json_schema[:exclusiveMinimum]
          constraints[:less_than] = json_schema[:exclusiveMaximum] if json_schema[:exclusiveMaximum]
          {_type: "number", constraints: constraints}

        when "integer"
          constraints = {}
          constraints[:min] = json_schema[:minimum] if json_schema[:minimum]
          constraints[:max] = json_schema[:maximum] if json_schema[:maximum]
          constraints[:greater_than] = json_schema[:exclusiveMinimum] if json_schema[:exclusiveMinimum]
          constraints[:less_than] = json_schema[:exclusiveMaximum] if json_schema[:exclusiveMaximum]
          {_type: "integer", constraints: constraints}

        when "boolean"
          {_type: "boolean"}

        when "null"
          {_type: "null"}

        when "array"
          if json_schema[:prefixItems]
            # Tuple
            {
              _type: "tuple",
              elements: json_schema[:prefixItems].map { |item| json_schema_to_ast(item) }
            }
          else
            # Array
            constraints = {}
            constraints[:min] = json_schema[:minItems] if json_schema[:minItems]
            constraints[:max] = json_schema[:maxItems] if json_schema[:maxItems]
            {
              _type: "array",
              item_type: json_schema[:items] ? json_schema_to_ast(json_schema[:items]) : {_type: "string"},
              constraints: constraints
            }
          end

        when "object"
          if json_schema[:additionalProperties] && !json_schema[:properties]
            # Record type
            value_type = json_schema[:additionalProperties].is_a?(Hash) ?
              json_schema_to_ast(json_schema[:additionalProperties]) :
              {_type: "string"}
            {
              _type: "record",
              key_type: {_type: "string"},
              value_type: value_type
            }
          else
            # Struct type
            fields = {}
            required = json_schema[:required] || []

            json_schema[:properties]&.each do |key, prop_schema|
              field_ast = json_schema_to_ast(prop_schema)

              # Wrap optional fields
              unless required.include?(key.to_s)
                if prop_schema[:default]
                  field_ast = {
                    _type: "optional",
                    inner_type: field_ast,
                    default_value: prop_schema[:default]
                  }
                end
              end

              fields[key.to_s] = field_ast
            end

            {
              _type: "struct",
              fields: fields,
              required: required
            }
          end

        else
          raise "Unsupported JSON Schema type: #{type}"
        end
      end
    end
  end
end
