# frozen_string_literal: true

require "raggio-schema"

module Raggio
  module JsonSchema
    class Generator
      def self.generate(schema_class, id: nil, title: nil, description: nil)
        new.generate(schema_class, id: id, title: title, description: description)
      end

      def generate(schema_class, id: nil, title: nil, description: nil)
        schema_type = (schema_class.is_a?(Class) && schema_class < Raggio::Schema::Base) ?
          schema_class.schema_type :
          schema_class

        result = convert_type(schema_type)

        result[:$schema] = "https://json-schema.org/draft/2020-12/schema" if id
        result[:$id] = id if id
        result[:title] = title if title
        result[:description] = description if description

        result
      end

      private

      def convert_type(type)
        case type
        when Raggio::Schema::IntegerType
          convert_integer(type)
        when Raggio::Schema::NumberType
          convert_number(type)
        when Raggio::Schema::StringType
          convert_string(type)
        when Raggio::Schema::BooleanType
          {type: "boolean"}
        when Raggio::Schema::NullType
          {type: "null"}
        when Raggio::Schema::SymbolType
          {type: "string"}
        when Raggio::Schema::LiteralType
          convert_literal(type)
        when Raggio::Schema::ArrayType
          convert_array(type)
        when Raggio::Schema::TupleType
          convert_tuple(type)
        when Raggio::Schema::StructType
          convert_struct(type)
        when Raggio::Schema::RecordType
          convert_record(type)
        when Raggio::Schema::UnionType
          convert_union(type)
        when Raggio::Schema::DiscriminatedUnionType
          convert_discriminated_union(type)
        when Raggio::Schema::LazyType
          convert_type(type.resolve)
        else
          raise "Unsupported type: #{type.class}"
        end
      end

      def convert_string(type)
        result = {type: "string"}
        result[:minLength] = type.constraints[:min] if type.constraints[:min]
        result[:maxLength] = type.constraints[:max] if type.constraints[:max]
        result[:pattern] = type.constraints[:format].source if type.constraints[:format]
        result
      end

      def convert_number(type)
        result = {type: "number"}
        result[:minimum] = type.constraints[:min] if type.constraints[:min]
        result[:maximum] = type.constraints[:max] if type.constraints[:max]
        result[:exclusiveMinimum] = type.constraints[:greater_than] if type.constraints[:greater_than]
        result[:exclusiveMaximum] = type.constraints[:less_than] if type.constraints[:less_than]
        result
      end

      def convert_integer(type)
        result = {type: "integer"}
        result[:minimum] = type.constraints[:min] if type.constraints[:min]
        result[:maximum] = type.constraints[:max] if type.constraints[:max]
        result[:exclusiveMinimum] = type.constraints[:greater_than] if type.constraints[:greater_than]
        result[:exclusiveMaximum] = type.constraints[:less_than] if type.constraints[:less_than]
        result
      end

      def convert_literal(type)
        if type.values.length == 1
          {const: type.values.first}
        else
          {enum: type.values}
        end
      end

      def convert_array(type)
        result = {type: "array"}
        result[:items] = convert_type(type.type)
        result[:minItems] = type.constraints[:min] if type.constraints[:min]
        result[:maxItems] = type.constraints[:max] if type.constraints[:max]
        result
      end

      def convert_tuple(type)
        {
          type: "array",
          prefixItems: type.elements.map { |el| convert_type(el) },
          minItems: type.elements.length,
          maxItems: type.elements.length
        }
      end

      def convert_struct(type)
        result = {type: "object"}

        properties = {}
        required = []

        type.fields.each do |key, field_type|
          is_optional = field_type.is_a?(Raggio::Schema::OptionalField)
          actual_type = is_optional ? field_type.type : field_type

          properties[key.to_s] = convert_type(actual_type)

          if is_optional && field_type.has_default?
            properties[key.to_s][:default] = field_type.default_value
          end

          required << key.to_s unless is_optional
        end

        result[:properties] = properties unless properties.empty?
        result[:required] = required unless required.empty?
        result[:additionalProperties] = false

        result
      end

      def convert_record(type)
        {
          type: "object",
          additionalProperties: convert_type(type.value_type)
        }
      end

      def convert_union(type)
        converted_members = type.members.map { |member| convert_type(member) }

        if converted_members.length == 2 && converted_members.any? { |m| m == {type: "null"} }
          non_null = converted_members.find { |m| m != {type: "null"} }
          return non_null.merge({type: [non_null[:type], "null"]}) if non_null[:type]
        end

        {anyOf: converted_members}
      end

      def convert_discriminated_union(type)
        {
          oneOf: type.variants.map { |_key, variant_type| convert_type(variant_type) }
        }
      end
    end
  end
end
