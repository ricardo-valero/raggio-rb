# frozen_string_literal: true

module Raggio
  module Schema
    class StringType < Type
      def decode(value)
        raise ValidationError, "Expected string, got #{value.class}" unless value.is_a?(String)

        if constraints[:min] && value.length < constraints[:min]
          raise ValidationError, "String length must be at least #{constraints[:min]}"
        end

        if constraints[:max] && value.length > constraints[:max]
          raise ValidationError, "String length must be at most #{constraints[:max]}"
        end

        if constraints[:format] && !constraints[:format].match?(value)
          raise ValidationError, "String must match format #{constraints[:format].inspect}"
        end

        value
      end
    end

    class NumberType < Type
      def decode(value)
        raise ValidationError, "Expected number, got #{value.class}" unless value.is_a?(Numeric)

        validate_constraints(value)

        value
      end

      private

      def validate_constraints(value)
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

    class IntegerType < NumberType
      def decode(value)
        raise ValidationError, "Expected integer, got #{value.class}" unless value.is_a?(Integer)

        validate_constraints(value)

        value
      end
    end

    class BooleanType < Type
      def decode(value)
        unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
          raise ValidationError, "Expected boolean, got #{value.class}"
        end

        value
      end
    end

    class SymbolType < Type
      def decode(value)
        raise ValidationError, "Expected symbol, got #{value.class}" unless value.is_a?(Symbol)

        value
      end
    end

    class NullType < Type
      def decode(value)
        raise ValidationError, "Expected nil, got #{value.class}" unless value.nil?

        nil
      end
    end
  end
end
