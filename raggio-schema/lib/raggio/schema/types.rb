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

        if constraints[:in] && !constraints[:in].include?(value)
          raise ValidationError, "String must be one of #{constraints[:in].inspect}"
        end

        if constraints[:format] && !constraints[:format].match?(value)
          raise ValidationError, "String must match format #{constraints[:format].inspect}"
        end
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

        if constraints[:max] && value > constraints[:max]
          raise ValidationError, "Number must be at most #{constraints[:max]}"
        end
      end
    end

    class BooleanType < Type
      def validate(value)
        unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
          raise ValidationError, "Expected boolean, got #{value.class}"
        end
      end
    end

    class LiteralType < Type
      attr_reader :values

      def initialize(*values)
        super()
        @values = values
      end

      def validate(value)
        unless @values.include?(value)
          raise ValidationError, "Expected one of #{@values.inspect}, got #{value.inspect}"
        end
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

          if extra_keys.any?
            raise ValidationError, "Unexpected keys: #{extra_keys.inspect}"
          end
        end

        fields.each do |key, type|
          field_value = value.key?(key) ? value[key] : value[key.to_s]

          is_optional_field = (type.is_a?(Type) && type.optional) || false

          if field_value.nil? && !is_optional_field
            raise ValidationError, "Field '#{key}' is required"
          end

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
            result[key] = type.decode(field_value)
          else
            result[key] = type.decode(field_value)
          end
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
            result[key] = type.encode(field_value)
          else
            result[key] = type.encode(field_value)
          end
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

        if constraints[:unique] && value.length != value.uniq.length
          raise ValidationError, "Array items must be unique"
        end

        value.each_with_index do |item, index|
          begin
            if type.is_a?(Class) && type < Raggio::Schema::Base
              type.schema_type.validate(item)
            else
              type.validate(item)
            end
          rescue ValidationError => e
            raise ValidationError, "Array item at index #{index}: #{e.message}"
          end
        end
      end

      def decode(value)
        return nil if value.nil? && @optional
        raise ValidationError, "Value cannot be nil" if value.nil?

        validate(value)

        value.map do |item|
          if type.is_a?(Class) && type < Raggio::Schema::Base
            type.decode(item)
          else
            type.decode(item)
          end
        end
      end

      def encode(value)
        return nil if value.nil?

        value.map do |item|
          if type.is_a?(Class) && type < Raggio::Schema::Base
            type.encode(item)
          else
            type.encode(item)
          end
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
