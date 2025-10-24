# frozen_string_literal: true

require "raggio-json-schema"

RSpec.describe Raggio::JsonSchema::Schema do
  it "validates a simple string schema" do
    schema = {
      type: "string",
      minLength: 1,
      maxLength: 100
    }

    result = Raggio::JsonSchema::Schema.decode(schema)
    expect(result[:type]).to eq("string")
    expect(result[:minLength]).to eq(1)
    expect(result[:maxLength]).to eq(100)
  end

  it "validates a number schema with constraints" do
    schema = {
      type: "number",
      minimum: 0,
      maximum: 100,
      multipleOf: 5
    }

    result = Raggio::JsonSchema::Schema.decode(schema)
    expect(result[:type]).to eq("number")
    expect(result[:minimum]).to eq(0)
    expect(result[:maximum]).to eq(100)
    expect(result[:multipleOf]).to eq(5)
  end

  it "validates an object schema with properties" do
    schema = {
      type: "object",
      properties: {
        name: { type: "string" },
        age: { type: "integer", minimum: 0 }
      },
      required: ["name"]
    }

    result = Raggio::JsonSchema::Schema.decode(schema)
    expect(result[:type]).to eq("object")
    expect(result[:properties]["name"][:type]).to eq("string")
    expect(result[:properties]["age"][:type]).to eq("integer")
    expect(result[:required]).to eq(["name"])
  end

  it "validates an array schema" do
    schema = {
      type: "array",
      items: { type: "string" },
      minItems: 1,
      uniqueItems: true
    }

    result = Raggio::JsonSchema::Schema.decode(schema)
    expect(result[:type]).to eq("array")
    expect(result[:items][:type]).to eq("string")
    expect(result[:minItems]).to eq(1)
    expect(result[:uniqueItems]).to eq(true)
  end

  it "validates enum schema" do
    schema = {
      enum: ["red", "green", "blue"]
    }

    result = Raggio::JsonSchema::Schema.decode(schema)
    expect(result[:enum]).to eq(["red", "green", "blue"])
  end

  it "validates const schema" do
    schema = {
      const: "active"
    }

    result = Raggio::JsonSchema::Schema.decode(schema)
    expect(result[:const]).to eq("active")
  end

  it "validates oneOf schema" do
    schema = {
      oneOf: [
        { type: "string" },
        { type: "number" }
      ]
    }

    result = Raggio::JsonSchema::Schema.decode(schema)
    expect(result[:oneOf].length).to eq(2)
    expect(result[:oneOf][0][:type]).to eq("string")
    expect(result[:oneOf][1][:type]).to eq("number")
  end

  it "validates $ref schema" do
    schema = {
      "$ref": "#/$defs/address"
    }

    result = Raggio::JsonSchema::Schema.decode(schema)
    expect(result[:"$ref"]).to eq("#/$defs/address")
  end

  it "validates nested object schema" do
    schema = {
      type: "object",
      properties: {
        address: {
          type: "object",
          properties: {
            street: { type: "string" },
            city: { type: "string" }
          },
          required: ["street", "city"]
        }
      }
    }

    result = Raggio::JsonSchema::Schema.decode(schema)
    expect(result[:type]).to eq("object")
    expect(result[:properties]["address"][:type]).to eq("object")
    expect(result[:properties]["address"][:properties]["street"][:type]).to eq("string")
  end

  it "validates comprehensive product schema" do
    schema = {
      type: "object",
      properties: {
        productId: {
          type: "integer",
          minimum: 1
        },
        productName: {
          type: "string",
          minLength: 1,
          maxLength: 100
        },
        price: {
          type: "number",
          minimum: 0,
          exclusiveMinimum: true
        },
        tags: {
          type: "array",
          items: { type: "string" },
          minItems: 1,
          uniqueItems: true
        },
        status: {
          enum: ["available", "discontinued", "pre-order"]
        }
      },
      required: ["productId", "productName", "price"]
    }

    result = Raggio::JsonSchema::Schema.decode(schema)
    expect(result[:type]).to eq("object")
    expect(result[:properties]["productId"][:type]).to eq("integer")
    expect(result[:properties]["price"][:exclusiveMinimum]).to eq(true)
    expect(result[:required]).to eq(["productId", "productName", "price"])
  end

  it "rejects invalid schema" do
    schema = {
      type: "invalid_type"
    }

    expect { Raggio::JsonSchema::Schema.decode(schema) }.to raise_error(
      Raggio::Schema::ValidationError
    )
  end
end
