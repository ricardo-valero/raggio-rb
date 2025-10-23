# frozen_string_literal: true

# Composite types contain other types as members or elements:
#
# - LiteralType: Validates exact value matches
# - UnionType: Contains member types (ordered members)
# - StructType: Contains field types (named members)
# - ArrayType: Contains single element type
# - TupleType: Contains multiple element types (fixed positions)
# - RecordType: Contains key/value types (dynamic keys)

module Raggio
  module Schema
    class LiteralType < Type
      attr_reader :values

      def initialize(*values)
        super()
        @values = values
      end

      def validate(value)
        return if @values.include?(value)

        raise ValidationError, "Expected one of #{@values.inspect}, got #{value.inspect}"
      end
    end

    class UnionType < Type
      attr_reader :members

      def initialize(*members)
        super()
        @members = members
      end

      def validate(value)
        errors = []
        valid = @members.any? do |member|
          if member.is_a?(Class) && member < Raggio::Schema::Base
            member.schema_type.validate(value)
          else
            member.validate(value)
          end
          true
        rescue ValidationError => e
          errors << e.message
          false
        end

        return if valid

        raise ValidationError, "Union validation failed:\n#{errors.map { |e| "  - #{e}" }.join("\n")}"
      end

      def decode(value)
        errors = []

        @members.each do |member|
          return member.decode(value) if member.is_a?(Class) && member < Raggio::Schema::Base

          return member.decode(value)
        rescue ValidationError => e
          errors << e.message
        end

        raise ValidationError, "Union decoding failed:\n#{errors.map { |e| "  - #{e}" }.join("\n")}"
      end

      def encode(value)
        return nil if value.nil?

        errors = []

        @members.each do |member|
          if member.is_a?(Class) && member < Raggio::Schema::Base
            member.schema_type.validate(value)
          else
            member.validate(value)
          end
          return member.encode(value)
        rescue ValidationError => e
          errors << e.message
        end

        raise ValidationError, "Union encoding failed:\n#{errors.map { |e| "  - #{e}" }.join("\n")}"
      end
    end

    class StructType < Type
      attr_reader :fields

      def initialize(fields, **constraints)
        super(**constraints)
        @fields = fields
      end

      def validate(value)
        raise ValidationError, "Expected hash, got #{value.class}" unless value.is_a?(Hash)

        extra_keys_mode = constraints[:extra_keys] || :reject

        if extra_keys_mode == :reject
          value_keys = value.keys.map(&:to_sym)
          field_keys = fields.keys.map(&:to_sym)
          extra_keys = value_keys - field_keys

          raise ValidationError, "Unexpected keys: #{extra_keys.inspect}" if extra_keys.any?
        end

        fields.each do |key, field_type|
          is_optional_field = field_type.is_a?(OptionalField)
          actual_type = is_optional_field ? field_type.type : field_type

          has_key = value.key?(key) || value.key?(key.to_s)
          field_value = value.key?(key) ? value[key] : value[key.to_s]

          raise ValidationError, "Field '#{key}' is required" if !has_key && !is_optional_field

          next if !has_key && is_optional_field

          if actual_type.is_a?(Class) && actual_type < Raggio::Schema::Base
            actual_type.schema_type.validate(field_value)
          else
            actual_type.validate(field_value)
          end
        end
      end

      def decode(value)
        raise ValidationError, "Value cannot be nil" if value.nil?

        validate(value)

        extra_keys_mode = constraints[:extra_keys] || :reject

        result = {}
        fields.each do |key, field_type|
          is_optional_field = field_type.is_a?(OptionalField)
          actual_type = is_optional_field ? field_type.type : field_type

          has_key = value.key?(key) || value.key?(key.to_s)
          next if !has_key && is_optional_field

          field_value = value.key?(key) ? value[key] : value[key.to_s]

          if actual_type.is_a?(Class) && actual_type < Raggio::Schema::Base
          end
          result[key] = actual_type.decode(field_value)
        end

        if extra_keys_mode == :include
          value_keys = value.keys.map(&:to_sym)
          field_keys = fields.keys.map(&:to_sym)
          extra_keys = value_keys - field_keys

          extra_keys.each do |key|
            result[key] = value.key?(key) ? value[key] : value[key.to_s]
          end
        end

        result
      end

      def encode(value)
        return nil if value.nil?

        result = {}
        fields.each do |key, field_type|
          is_optional_field = field_type.is_a?(OptionalField)
          actual_type = is_optional_field ? field_type.type : field_type

          has_key = value.key?(key) || value.key?(key.to_s)
          next if !has_key && is_optional_field

          field_value = value.key?(key) ? value[key] : value[key.to_s]

          if actual_type.is_a?(Class) && actual_type < Raggio::Schema::Base
          end
          result[key] = actual_type.encode(field_value)
        end
        result
      end
    end

    class ArrayType < Type
      attr_reader :type

      def initialize(type, **constraints)
        super(**constraints)
        @type = type
      end

      def validate(value)
        raise ValidationError, "Expected array, got #{value.class}" unless value.is_a?(Array)

        if constraints[:min] && value.length < constraints[:min]
          raise ValidationError, "Array length must be at least #{constraints[:min]}"
        end

        if constraints[:max] && value.length > constraints[:max]
          raise ValidationError, "Array length must be at most #{constraints[:max]}"
        end

        if constraints[:length] && value.length != constraints[:length]
          raise ValidationError, "Array length must be exactly #{constraints[:length]}"
        end

        raise ValidationError, "Array items must be unique" if constraints[:unique] && value.length != value.uniq.length

        value.each_with_index do |item, index|
          if type.is_a?(Class) && type < Raggio::Schema::Base
            type.schema_type.validate(item)
          else
            type.validate(item)
          end
        rescue ValidationError => e
          raise ValidationError, "Array item at index #{index}: #{e.message}"
        end
      end

      def decode(value)
        raise ValidationError, "Value cannot be nil" if value.nil?

        validate(value)

        value.map do |item|
          if type.is_a?(Class) && type < Raggio::Schema::Base
          end
          type.decode(item)
        end
      end

      def encode(value)
        return nil if value.nil?

        value.map do |item|
          if type.is_a?(Class) && type < Raggio::Schema::Base
          end
          type.encode(item)
        end
      end
    end

    class TupleType < Type
      attr_reader :elements

      def initialize(*elements)
        super()
        @elements = elements
      end

      def validate(value)
        raise ValidationError, "Expected array, got #{value.class}" unless value.is_a?(Array)

        if value.length != @elements.length
          raise ValidationError, "Expected exactly #{@elements.length} elements, got #{value.length}"
        end

        @elements.each_with_index do |element_type, index|
          item = value[index]
          if element_type.is_a?(Class) && element_type < Raggio::Schema::Base
            element_type.schema_type.validate(item)
          else
            element_type.validate(item)
          end
        rescue ValidationError => e
          raise ValidationError, "Tuple element at index #{index}: #{e.message}"
        end
      end

      def decode(value)
        raise ValidationError, "Value cannot be nil" if value.nil?

        validate(value)

        @elements.map.with_index do |element_type, index|
          item = value[index]
          element_type = element_type.schema_type if element_type.is_a?(Class) && element_type < Raggio::Schema::Base
          element_type.decode(item)
        end
      end

      def encode(value)
        return nil if value.nil?

        @elements.map.with_index do |element_type, index|
          item = value[index]
          element_type = element_type.schema_type if element_type.is_a?(Class) && element_type < Raggio::Schema::Base
          element_type.encode(item)
        end
      end
    end

    class RecordType < Type
      attr_reader :key_type, :value_type

      def initialize(key:, value:)
        super()
        @key_type = key
        @value_type = value
      end

      def validate(value)
        raise ValidationError, "Expected hash, got #{value.class}" unless value.is_a?(Hash)

        value.each do |k, v|
          key = k.is_a?(Symbol) ? k.to_s : k
          begin
            key_type.validate(key)
          rescue ValidationError => e
            raise ValidationError, "Invalid key #{k.inspect}: #{e.message}"
          end

          begin
            value_type_to_use = (value_type.is_a?(Class) && value_type < Raggio::Schema::Base) ? value_type.schema_type : value_type
            value_type_to_use.validate(v)
          rescue ValidationError => e
            raise ValidationError, "Invalid value for key #{k.inspect}: #{e.message}"
          end
        end
      end

      def decode(value)
        raise ValidationError, "Value cannot be nil" if value.nil?

        validate(value)

        result = {}
        value.each do |k, v|
          key = k.is_a?(Symbol) ? k.to_s : k
          decoded_key = key_type.decode(key)

          value_type_to_use = (value_type.is_a?(Class) && value_type < Raggio::Schema::Base) ? value_type.schema_type : value_type
          decoded_value = value_type_to_use.decode(v)

          result[decoded_key] = decoded_value
        end
        result
      end

      def encode(value)
        return nil if value.nil?

        result = {}
        value.each do |k, v|
          encoded_key = key_type.encode(k)

          value_type_to_use = (value_type.is_a?(Class) && value_type < Raggio::Schema::Base) ? value_type.schema_type : value_type
          encoded_value = value_type_to_use.encode(v)

          result[encoded_key] = encoded_value
        end
        result
      end
    end
  end
end
