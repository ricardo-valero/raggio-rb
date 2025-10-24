# frozen_string_literal: true

module Raggio
  module Schema
    # Converts Raggio Schema Type instances to AST hashes
    module Introspection
      def self.type_to_ast(type)
        case type
        when Raggio::Schema::StringType
          {
            _type: "string",
            constraints: extract_constraints(type, [:min, :max, :format])
          }
        when Raggio::Schema::IntegerType
          {
            _type: "integer",
            constraints: extract_constraints(type, [:min, :max, :greater_than, :less_than])
          }
        when Raggio::Schema::NumberType
          {
            _type: "number",
            constraints: extract_constraints(type, [:min, :max, :greater_than, :less_than])
          }
        when Raggio::Schema::BooleanType
          {_type: "boolean"}
        when Raggio::Schema::NullType
          {_type: "null"}
        when Raggio::Schema::SymbolType
          {_type: "symbol"}
        when Raggio::Schema::LiteralType
          {
            _type: "literal",
            values: type.values
          }
        when Raggio::Schema::ArrayType
          {
            _type: "array",
            item_type: type_to_ast(type.type),
            constraints: extract_constraints(type, [:min, :max])
          }
        when Raggio::Schema::TupleType
          {
            _type: "tuple",
            elements: type.elements.map { |el| type_to_ast(el) }
          }
        when Raggio::Schema::StructType
          fields = {}
          required = []
          type.fields.each do |key, field_type|
            if field_type.is_a?(Raggio::Schema::OptionalField)
              field_ast = type_to_ast(field_type.type)
              if field_type.has_default?
                field_ast = {
                  _type: "optional",
                  inner_type: field_ast,
                  default_value: field_type.default_value
                }
              end
              fields[key.to_s] = field_ast
            else
              fields[key.to_s] = type_to_ast(field_type)
              required << key.to_s
            end
          end
          {
            _type: "struct",
            fields: fields,
            required: required
          }
        when Raggio::Schema::RecordType
          {
            _type: "record",
            key_type: type_to_ast(type.key_type),
            value_type: type_to_ast(type.value_type)
          }
        when Raggio::Schema::UnionType
          {
            _type: "union",
            members: type.members.map { |m| type_to_ast(m) }
          }
        when Raggio::Schema::DiscriminatedUnionType
          variants = {}
          type.variants.each do |key, variant|
            variants[key.to_s] = type_to_ast(variant)
          end
          {
            _type: "discriminated_union",
            discriminator: type.discriminator.to_s,
            variants: variants
          }
        when Raggio::Schema::OptionalField
          result = {
            _type: "optional",
            inner_type: type_to_ast(type.type)
          }
          result[:default_value] = type.default_value if type.has_default?
          result
        when Raggio::Schema::LazyType
          {
            _type: "lazy",
            inner_type: type_to_ast(type.resolve)
          }
        else
          raise "Unsupported type: #{type.class}"
        end
      end

      def self.extract_constraints(type, keys)
        result = {}
        keys.each do |key|
          value = type.constraints[key]
          result[key] = value if value
        end
        result
      end
    end
  end
end
