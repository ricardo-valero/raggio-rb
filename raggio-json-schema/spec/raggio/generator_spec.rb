# frozen_string_literal: true

require "raggio-json-schema"
require "json"

RSpec.describe Raggio::JsonSchema::Generator do
  it "generates JSON Schema for simple string" do
    schema = Class.new(Raggio::Schema::Base) do
      string
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:type]).to eq("string")
  end

  it "generates JSON Schema for string with constraints" do
    schema = Class.new(Raggio::Schema::Base) do
      string(min: 5, max: 100)
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:type]).to eq("string")
    expect(result[:minLength]).to eq(5)
    expect(result[:maxLength]).to eq(100)
  end

  it "generates JSON Schema for number with constraints" do
    schema = Class.new(Raggio::Schema::Base) do
      number(min: 0, max: 100)
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:type]).to eq("number")
    expect(result[:minimum]).to eq(0)
    expect(result[:maximum]).to eq(100)
  end

  it "generates JSON Schema for integer" do
    schema = Class.new(Raggio::Schema::Base) do
      integer(min: 1)
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:type]).to eq("integer")
    expect(result[:minimum]).to eq(1)
  end

  it "generates JSON Schema for literal with single value" do
    schema = Class.new(Raggio::Schema::Base) do
      literal("active")
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:const]).to eq("active")
  end

  it "generates JSON Schema for literal with multiple values" do
    schema = Class.new(Raggio::Schema::Base) do
      literal("active", "inactive", "pending")
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:enum]).to eq(["active", "inactive", "pending"])
  end

  it "generates JSON Schema for array" do
    schema = Class.new(Raggio::Schema::Base) do
      array(string, min: 1)
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:type]).to eq("array")
    expect(result[:items][:type]).to eq("string")
    expect(result[:minItems]).to eq(1)
  end

  it "generates JSON Schema for tuple" do
    schema = Class.new(Raggio::Schema::Base) do
      tuple(string, number, boolean)
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:type]).to eq("array")
    expect(result[:prefixItems].length).to eq(3)
    expect(result[:prefixItems][0][:type]).to eq("string")
    expect(result[:prefixItems][1][:type]).to eq("number")
    expect(result[:prefixItems][2][:type]).to eq("boolean")
    expect(result[:minItems]).to eq(3)
    expect(result[:maxItems]).to eq(3)
  end

  it "generates JSON Schema for struct" do
    schema = Class.new(Raggio::Schema::Base) do
      struct({
        name: string,
        age: integer(min: 0),
        email: optional(string)
      })
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:type]).to eq("object")
    expect(result[:properties]["name"][:type]).to eq("string")
    expect(result[:properties]["age"][:type]).to eq("integer")
    expect(result[:properties]["age"][:minimum]).to eq(0)
    expect(result[:properties]["email"][:type]).to eq("string")
    expect(result[:required]).to eq(["name", "age"])
    expect(result[:additionalProperties]).to eq(false)
  end

  it "generates JSON Schema for struct with defaults" do
    schema = Class.new(Raggio::Schema::Base) do
      struct({
        name: string,
        port: optional(integer, 3000)
      })
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:properties]["port"][:default]).to eq(3000)
  end

  it "generates JSON Schema for record" do
    schema = Class.new(Raggio::Schema::Base) do
      record(key: string, value: number)
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:type]).to eq("object")
    expect(result[:additionalProperties][:type]).to eq("number")
  end

  it "generates JSON Schema for nullable" do
    schema = Class.new(Raggio::Schema::Base) do
      nullable(string)
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:type]).to include("string", "null")
  end

  it "generates JSON Schema for union" do
    schema = Class.new(Raggio::Schema::Base) do
      union(string, number, boolean)
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:anyOf].length).to eq(3)
    expect(result[:anyOf][0][:type]).to eq("string")
    expect(result[:anyOf][1][:type]).to eq("number")
    expect(result[:anyOf][2][:type]).to eq("boolean")
  end

  it "generates JSON Schema for discriminated union" do
    schema = Class.new(Raggio::Schema::Base) do
      discriminated_union(:type,
        circle: struct({type: literal("circle"), radius: number}),
        square: struct({type: literal("square"), side: number}))
    end

    result = Raggio::JsonSchema.generate(schema)
    expect(result[:oneOf].length).to eq(2)
    expect(result[:oneOf][0][:properties]["type"][:const]).to eq("circle")
    expect(result[:oneOf][1][:properties]["type"][:const]).to eq("square")
  end

  it "generates comprehensive product schema" do
    product_schema = Class.new(Raggio::Schema::Base) do
      struct({
        productId: integer(min: 1),
        productName: string(min: 1, max: 100),
        price: number(min: 0),
        tags: optional(array(string, min: 1)),
        status: literal("available", "discontinued", "pre-order"),
        dimensions: optional(struct({
          length: number,
          width: number,
          height: number
        }))
      })
    end

    result = Raggio::JsonSchema.generate(
      product_schema,
      id: "https://example.com/product.schema.json",
      title: "Product",
      description: "A product from Acme's catalog"
    )

    expect(result[:$schema]).to eq("https://json-schema.org/draft/2020-12/schema")
    expect(result[:$id]).to eq("https://example.com/product.schema.json")
    expect(result[:title]).to eq("Product")
    expect(result[:description]).to eq("A product from Acme's catalog")
    expect(result[:type]).to eq("object")

    expect(result[:properties]["productId"][:type]).to eq("integer")
    expect(result[:properties]["productId"][:minimum]).to eq(1)

    expect(result[:properties]["productName"][:type]).to eq("string")
    expect(result[:properties]["productName"][:minLength]).to eq(1)
    expect(result[:properties]["productName"][:maxLength]).to eq(100)

    expect(result[:properties]["price"][:type]).to eq("number")
    expect(result[:properties]["price"][:minimum]).to eq(0)

    expect(result[:properties]["tags"][:type]).to eq("array")
    expect(result[:properties]["tags"][:items][:type]).to eq("string")
    expect(result[:properties]["tags"][:minItems]).to eq(1)

    expect(result[:properties]["status"][:enum]).to eq(["available", "discontinued", "pre-order"])

    expect(result[:properties]["dimensions"][:type]).to eq("object")
    expect(result[:properties]["dimensions"][:properties]["length"][:type]).to eq("number")

    expect(result[:required]).to eq(["productId", "productName", "price", "status"])

    puts "\nGenerated JSON Schema:"
    puts JSON.pretty_generate(JSON.parse(result.to_json))
  end

  it "validates the generated JSON Schema using our Schema validator" do
    product_schema = Class.new(Raggio::Schema::Base) do
      struct({
        productId: integer(min: 1),
        productName: string(min: 1, max: 100),
        price: number(min: 0)
      })
    end

    result = Raggio::JsonSchema.generate(product_schema)

    expect {
      Raggio::JsonSchema::Schema.decode(result)
    }.not_to raise_error
  end
end
