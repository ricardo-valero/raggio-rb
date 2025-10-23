# frozen_string_literal: true

module Raggio
  module Schema
    class Type
      attr_reader :constraints

      def initialize(**constraints)
        @constraints = constraints
      end

      def validate(value)
        raise NotImplementedError
      end

      def encode(value)
        value
      end

      def decode(value)
        raise ValidationError, "Value cannot be nil" if value.nil?

        validate(value)
        value
      end
    end

    class OptionalField
      attr_reader :type

      def initialize(type)
        @type = type
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
