# frozen_string_literal: true

module Raggio
  module Schema
    class Type
      attr_reader :constraints

      def initialize(**constraints)
        @constraints = constraints
      end

      def encode(value)
        value
      end

      def decode(value)
        raise NotImplementedError
      end
    end

    class OptionalField
      attr_reader :type, :default_value

      def initialize(type, default_value = nil)
        @type = type
        @default_value = default_value
        @has_default = !default_value.nil?
        validate_default! if @has_default
      end

      def has_default?
        @has_default
      end

      private

      def validate_default!
        actual_type = (@type.is_a?(Class) && @type < Raggio::Schema::Base) ? @type.schema_type : @type
        actual_type.decode(@default_value)
      rescue ValidationError => e
        raise ArgumentError, "Invalid default value: #{e.message}"
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

      def decode(value)
        decoded = from_type.decode(value)
        decode_fn.call(decoded)
      end

      def encode(value)
        return nil if value.nil?

        encoded = encode_fn.call(value)
        from_type.encode(encoded)
      end
    end

    class LazyType < Type
      attr_reader :schema_class

      def initialize(schema_class)
        super()
        @schema_class = schema_class
        @resolved = nil
      end

      def resolve
        @resolved ||= (@schema_class.is_a?(Class) && @schema_class < Raggio::Schema::Base) ?
            @schema_class.schema_type :
            @schema_class
      end

      def decode(value)
        resolve.decode(value)
      end

      def encode(value)
        resolve.encode(value)
      end
    end

    class ValidationError < StandardError; end
  end
end
