# frozen_string_literal: true

require "raggio-json-schema"
require "json"

RSpec.describe Raggio::JsonSchema::Codec do
  describe "ast_to_json_schema" do
    it "converts string AST to JSON Schema" do
      ast = {
        _type: "string",
        constraints: {min: 5, max: 100}
      }

      result = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)
      expect(result[:type]).to eq("string")
      expect(result[:minLength]).to eq(5)
      expect(result[:maxLength]).to eq(100)
    end

    it "converts integer AST to JSON Schema" do
      ast = {
        _type: "integer",
        constraints: {min: 0, max: 150}
      }

      result = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)
      expect(result[:type]).to eq("integer")
      expect(result[:minimum]).to eq(0)
      expect(result[:maximum]).to eq(150)
    end

    it "converts literal AST to JSON Schema const" do
      ast = {
        _type: "literal",
        values: ["active"]
      }

      result = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)
      expect(result[:const]).to eq("active")
    end

    it "converts literal AST to JSON Schema enum" do
      ast = {
        _type: "literal",
        values: ["active", "inactive", "pending"]
      }

      result = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)
      expect(result[:enum]).to eq(["active", "inactive", "pending"])
    end

    it "converts struct AST to JSON Schema object" do
      ast = {
        _type: "struct",
        fields: {
          "name" => {_type: "string", constraints: {}},
          "age" => {_type: "integer", constraints: {min: 0}}
        },
        required: ["name", "age"]
      }

      result = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)
      expect(result[:type]).to eq("object")
      expect(result[:properties]["name"][:type]).to eq("string")
      expect(result[:properties]["age"][:type]).to eq("integer")
      expect(result[:properties]["age"][:minimum]).to eq(0)
      expect(result[:required]).to eq(["name", "age"])
    end
  end

  describe "json_schema_to_ast" do
    it "converts JSON Schema string to AST" do
      json_schema = {
        type: "string",
        minLength: 5,
        maxLength: 100
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:_type]).to eq("string")
      expect(result[:constraints][:min]).to eq(5)
      expect(result[:constraints][:max]).to eq(100)
    end

    it "converts JSON Schema integer to AST" do
      json_schema = {
        type: "integer",
        minimum: 0,
        maximum: 150
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:_type]).to eq("integer")
      expect(result[:constraints][:min]).to eq(0)
      expect(result[:constraints][:max]).to eq(150)
    end

    it "converts JSON Schema const to literal AST" do
      json_schema = {
        const: "active"
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:_type]).to eq("literal")
      expect(result[:values]).to eq(["active"])
    end

    it "converts JSON Schema enum to literal AST" do
      json_schema = {
        enum: ["active", "inactive", "pending"]
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:_type]).to eq("literal")
      expect(result[:values]).to eq(["active", "inactive", "pending"])
    end

    it "converts JSON Schema object to struct AST" do
      json_schema = {
        type: "object",
        properties: {
          name: {type: "string"},
          age: {type: "integer", minimum: 0}
        },
        required: ["name", "age"]
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:_type]).to eq("struct")
      expect(result[:fields]["name"][:_type]).to eq("string")
      expect(result[:fields]["age"][:_type]).to eq("integer")
      expect(result[:fields]["age"][:constraints][:min]).to eq(0)
      expect(result[:required]).to eq(["name", "age"])
    end

    it "converts JSON Schema array to array AST" do
      json_schema = {
        type: "array",
        items: {type: "string"},
        minItems: 1,
        maxItems: 10
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:_type]).to eq("array")
      expect(result[:item_type][:_type]).to eq("string")
      expect(result[:constraints][:min]).to eq(1)
      expect(result[:constraints][:max]).to eq(10)
    end

    it "converts JSON Schema tuple (prefixItems) to tuple AST" do
      json_schema = {
        type: "array",
        prefixItems: [
          {type: "string"},
          {type: "number"},
          {type: "boolean"}
        ],
        minItems: 3,
        maxItems: 3
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:_type]).to eq("tuple")
      expect(result[:elements].length).to eq(3)
      expect(result[:elements][0][:_type]).to eq("string")
      expect(result[:elements][1][:_type]).to eq("number")
      expect(result[:elements][2][:_type]).to eq("boolean")
    end

    it "converts JSON Schema anyOf to union AST" do
      json_schema = {
        anyOf: [
          {type: "string"},
          {type: "number"}
        ]
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:_type]).to eq("union")
      expect(result[:members].length).to eq(2)
      expect(result[:members][0][:_type]).to eq("string")
      expect(result[:members][1][:_type]).to eq("number")
    end

    it "converts nullable type to union with null" do
      json_schema = {
        type: ["string", "null"]
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:_type]).to eq("union")
      expect(result[:members].length).to eq(2)
      expect(result[:members][0][:_type]).to eq("string")
      expect(result[:members][1][:_type]).to eq("null")
    end

    it "converts JSON Schema with default to optional AST" do
      json_schema = {
        type: "object",
        properties: {
          name: {type: "string"},
          port: {type: "integer", default: 3000}
        },
        required: ["name"]
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:fields]["port"][:_type]).to eq("optional")
      expect(result[:fields]["port"][:inner_type][:_type]).to eq("integer")
      expect(result[:fields]["port"][:default_value]).to eq(3000)
    end

    it "converts JSON Schema record (additionalProperties) to record AST" do
      json_schema = {
        type: "object",
        additionalProperties: {type: "number"}
      }

      result = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)
      expect(result[:_type]).to eq("record")
      expect(result[:key_type][:_type]).to eq("string")
      expect(result[:value_type][:_type]).to eq("number")
    end
  end

  describe "round-trip transformations" do
    it "round-trips string schema" do
      schema = Class.new(Raggio::Schema::Base) do
        string(min: 5, max: 100)
      end

      # Raggio → AST → JSON Schema
      ast = Raggio::Schema::Introspection.type_to_ast(schema.schema_type)
      json_schema = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)

      # JSON Schema → AST
      ast_back = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)

      expect(ast_back[:_type]).to eq("string")
      expect(ast_back[:constraints][:min]).to eq(5)
      expect(ast_back[:constraints][:max]).to eq(100)
    end

    it "round-trips integer schema with constraints" do
      schema = Class.new(Raggio::Schema::Base) do
        integer(min: 0, max: 150)
      end

      ast = Raggio::Schema::Introspection.type_to_ast(schema.schema_type)
      json_schema = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)
      ast_back = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)

      expect(ast_back[:_type]).to eq("integer")
      expect(ast_back[:constraints][:min]).to eq(0)
      expect(ast_back[:constraints][:max]).to eq(150)
    end

    it "round-trips literal schema" do
      schema = Class.new(Raggio::Schema::Base) do
        literal("active", "inactive", "pending")
      end

      ast = Raggio::Schema::Introspection.type_to_ast(schema.schema_type)
      json_schema = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)
      ast_back = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)

      expect(ast_back[:_type]).to eq("literal")
      expect(ast_back[:values]).to eq(["active", "inactive", "pending"])
    end

    it "round-trips struct schema" do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string,
          age: integer(min: 0)
        })
      end

      ast = Raggio::Schema::Introspection.type_to_ast(schema.schema_type)
      json_schema = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)
      ast_back = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)

      expect(ast_back[:_type]).to eq("struct")
      expect(ast_back[:fields]["name"][:_type]).to eq("string")
      expect(ast_back[:fields]["age"][:_type]).to eq("integer")
      expect(ast_back[:fields]["age"][:constraints][:min]).to eq(0)
      expect(ast_back[:required]).to eq(["name", "age"])
    end

    it "round-trips array schema" do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, min: 1)
      end

      ast = Raggio::Schema::Introspection.type_to_ast(schema.schema_type)
      json_schema = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)
      ast_back = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)

      expect(ast_back[:_type]).to eq("array")
      expect(ast_back[:item_type][:_type]).to eq("string")
      expect(ast_back[:constraints][:min]).to eq(1)
    end

    it "round-trips tuple schema" do
      schema = Class.new(Raggio::Schema::Base) do
        tuple(string, number, boolean)
      end

      ast = Raggio::Schema::Introspection.type_to_ast(schema.schema_type)
      json_schema = Raggio::JsonSchema::Codec.ast_to_json_schema(ast)
      ast_back = Raggio::JsonSchema::Codec.json_schema_to_ast(json_schema)

      expect(ast_back[:_type]).to eq("tuple")
      expect(ast_back[:elements].length).to eq(3)
      expect(ast_back[:elements][0][:_type]).to eq("string")
      expect(ast_back[:elements][1][:_type]).to eq("number")
      expect(ast_back[:elements][2][:_type]).to eq("boolean")
    end
  end
end
