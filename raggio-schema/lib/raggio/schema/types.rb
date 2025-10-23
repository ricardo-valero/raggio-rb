# frozen_string_literal: true

module Raggio
  module Schema
    class Type
      attr_reader :constraints, :optional

      def initialize(**constraints)
        @constraints = constraints
        @optional = false
      end

      def optional!
        @optional = true
        self
      end

      def validate(value)
        raise NotImplementedError
      end

      def encode(value)
        value
      end

      def decode(value)
        return nil if value.nil? && @optional
        raise ValidationError, "Value cannot be nil" if value.nil?

        validate(value)
        value
      end
    end

    class StringType < Type
      def validate(value)
        raise ValidationError, "Expected string, got #{value.class}" unless value.is_a?(String)

        if constraints[:min] && value.length < constraints[:min]
          raise ValidationError, "String length must be at least #{constraints[:min]}"
        end

        if constraints[:max] && value.length > constraints[:max]
          raise ValidationError, "String length must be at most #{constraints[:max]}"
        end

        return unless constraints[:format] && !constraints[:format].match?(value)

        raise ValidationError, "String must match format #{constraints[:format].inspect}"
      end
    end

    class NumberType < Type
      def validate(value)
        raise ValidationError, "Expected number, got #{value.class}" unless value.is_a?(Numeric)

        if constraints[:greater_than] && value <= constraints[:greater_than]
          raise ValidationError, "Number must be greater than #{constraints[:greater_than]}"
        end

        if constraints[:less_than] && value >= constraints[:less_than]
          raise ValidationError, "Number must be less than #{constraints[:less_than]}"
        end

        if constraints[:min] && value < constraints[:min]
          raise ValidationError, "Number must be at least #{constraints[:min]}"
        end

        return unless constraints[:max] && value > constraints[:max]

        raise ValidationError, "Number must be at most #{constraints[:max]}"
      end
    end

    class BooleanType < Type
      def validate(value)
        return if value.is_a?(TrueClass) || value.is_a?(FalseClass)

        raise ValidationError, "Expected boolean, got #{value.class}"
      end
    end

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
        return nil if value.nil? && @optional
        raise ValidationError, "Value cannot be nil" if value.nil?

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

        fields.each do |key, type|
          field_value = value.key?(key) ? value[key] : value[key.to_s]

          is_optional_field = (type.is_a?(Type) && type.optional) || false

          raise ValidationError, "Field '#{key}' is required" if field_value.nil? && !is_optional_field

          next if field_value.nil? && is_optional_field

          if type.is_a?(Class) && type < Raggio::Schema::Base
            type.schema_type.validate(field_value)
          else
            type.validate(field_value)
          end
        end
      end

      def decode(value)
        return nil if value.nil? && @optional
        raise ValidationError, "Value cannot be nil" if value.nil?

        validate(value)

        extra_keys_mode = constraints[:extra_keys] || :reject

        result = {}
        fields.each do |key, type|
          field_value = value.key?(key) ? value[key] : value[key.to_s]

          if type.is_a?(Class) && type < Raggio::Schema::Base
          end
          result[key] = type.decode(field_value)
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
        fields.each do |key, type|
          field_value = value.key?(key) ? value[key] : value[key.to_s]

          if type.is_a?(Class) && type < Raggio::Schema::Base
          end
          result[key] = type.encode(field_value)
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
        return nil if value.nil? && @optional
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
        return nil if value.nil? && @optional
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

    class TransformType < Type
      attr_reader :from_type, :to_type, :decode_fn, :encode_fn

      def initialize(from_type, to_type, decode:, encode:)
        super()
        @from_type = from_type
        @to_type = to_type
        @decode_fn = decode
        @encode_fn = encode
      end

      def validate(value)
        from_type.validate(value)
      end

      def decode(value)
        return nil if value.nil? && @optional
        raise ValidationError, "Value cannot be nil" if value.nil?

        decoded = from_type.decode(value)
        decode_fn.call(decoded)
      end

      def encode(value)
        return nil if value.nil?

        encoded = encode_fn.call(value)
        from_type.encode(encoded)
      end
    end

    class ValidationError < StandardError; end
  end
end
