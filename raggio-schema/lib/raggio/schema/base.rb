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

        def struct(fields)
          @schema_type = StructType.new(fields)
        end

        def array(item_type)
          @schema_type = ArrayType.new(item_type)
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
