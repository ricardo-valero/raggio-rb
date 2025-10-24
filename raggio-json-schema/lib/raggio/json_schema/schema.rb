# frozen_string_literal: true

require "raggio-schema"

module Raggio
  module JsonSchema
    class Schema < Raggio::Schema::Base
      union(
        discriminated_union(:type,
          string: struct({
            type: literal("string"),
            minLength: optional(number(min: 0)),
            maxLength: optional(number(min: 0)),
            pattern: optional(string),
            format: optional(literal(
              "date-time", "date", "time", "duration",
              "email", "idn-email",
              "hostname", "idn-hostname",
              "ipv4", "ipv6",
              "uri", "uri-reference", "iri", "iri-reference",
              "uuid",
              "uri-template",
              "json-pointer", "relative-json-pointer",
              "regex"
            ))
          }),

          number: struct({
            type: literal("number"),
            minimum: optional(number),
            maximum: optional(number),
            exclusiveMinimum: optional(union(number, boolean)),
            exclusiveMaximum: optional(union(number, boolean)),
            multipleOf: optional(number(min: 0))
          }),

          integer: struct({
            type: literal("integer"),
            minimum: optional(number),
            maximum: optional(number),
            exclusiveMinimum: optional(union(number, boolean)),
            exclusiveMaximum: optional(union(number, boolean)),
            multipleOf: optional(number(min: 0))
          }),

          boolean: struct({
            type: literal("boolean")
          }),

          null: struct({
            type: literal("null")
          }),

          array: struct({
            type: literal("array"),
            items: optional(lazy(Schema)),
            minItems: optional(number(min: 0)),
            maxItems: optional(number(min: 0)),
            uniqueItems: optional(boolean)
          }),

          object: struct({
            type: literal("object"),
            properties: optional(record(key: string, value: lazy(Schema))),
            required: optional(array(string)),
            additionalProperties: optional(union(boolean, lazy(Schema)))
          })
        ),

        struct({
          enum: array(union(string, number, boolean, null))
        }),

        struct({
          const: union(string, number, boolean, null)
        }),

        struct({
          anyOf: array(lazy(Schema))
        }),

        struct({
          oneOf: array(lazy(Schema))
        }),

        struct({
          allOf: array(lazy(Schema))
        }),

        struct({
          not: lazy(Schema)
        }),

        struct({
          "$ref": string
        })
      )
    end
  end
end
