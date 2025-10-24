# frozen_string_literal: true

module Raggio
  module Schema
    # This schema represents the AST structure of Raggio Schema itself
    class AST < Base
      union(
        discriminated_union(:_type,
          string: struct({
            _type: literal("string"),
            constraints: optional(struct({
              min: optional(integer(min: 0)),
              max: optional(integer(min: 0)),
              format: optional(string)
            }), {})
          }),

          number: struct({
            _type: literal("number"),
            constraints: optional(struct({
              min: optional(number),
              max: optional(number),
              greater_than: optional(number),
              less_than: optional(number)
            }), {})
          }),

          integer: struct({
            _type: literal("integer"),
            constraints: optional(struct({
              min: optional(number),
              max: optional(number),
              greater_than: optional(number),
              less_than: optional(number)
            }), {})
          }),

          boolean: struct({
            _type: literal("boolean")
          }),

          null: struct({
            _type: literal("null")
          }),

          symbol: struct({
            _type: literal("symbol")
          }),

          literal: struct({
            _type: literal("literal"),
            values: array(union(string, number, boolean, null))
          }),

          array: struct({
            _type: literal("array"),
            item_type: lazy(AST),
            constraints: optional(struct({
              min: optional(integer(min: 0)),
              max: optional(integer(min: 0))
            }), {})
          }),

          tuple: struct({
            _type: literal("tuple"),
            elements: array(lazy(AST))
          }),

          struct: struct({
            _type: literal("struct"),
            fields: record(key: string, value: lazy(AST)),
            required: array(string)
          }),

          record: struct({
            _type: literal("record"),
            key_type: lazy(AST),
            value_type: lazy(AST)
          }),

          union: struct({
            _type: literal("union"),
            members: array(lazy(AST))
          }),

          discriminated_union: struct({
            _type: literal("discriminated_union"),
            discriminator: string,
            variants: record(key: string, value: lazy(AST))
          }),

          optional: struct({
            _type: literal("optional"),
            inner_type: lazy(AST),
            default_value: optional(union(string, number, boolean, null, array(union(string, number, boolean, null))))
          }),

          lazy: struct({
            _type: literal("lazy"),
            inner_type: lazy(AST)
          }))
      )
    end
  end
end
