# frozen_string_literal: true

module Raggio
  module Schema
    class Base
      class << self
        attr_accessor :schema_type

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@schema_type, nil)
        end

        def string(**constraints)
          @schema_type = StringType.new(**constraints)
        end

        def number(**constraints)
          @schema_type = NumberType.new(**constraints)
        end

        def boolean
          @schema_type = BooleanType.new
        end

        def literal(*values)
          values = values.first if values.length == 1 && values.first.is_a?(Array)
          @schema_type = LiteralType.new(*values)
        end

        def union(*members)
          @schema_type = UnionType.new(*members)
        end

        def struct(fields, **constraints)
          @schema_type = StructType.new(fields, **constraints)
        end

        def array(type, **constraints)
          @schema_type = ArrayType.new(type, **constraints)
        end

        def optional(type)
          type.optional!
          type
        end

        def transform(from_type, to_type, decode:, encode:)
          @schema_type = TransformType.new(from_type, to_type, decode: decode, encode: encode)
        end

        def decode(value)
          raise "Schema not defined" unless @schema_type

          @schema_type.decode(value)
        end

        def encode(value)
          raise "Schema not defined" unless @schema_type

          @schema_type.encode(value)
        end
      end
    end
  end
end
