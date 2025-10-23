# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

RSpec.describe Raggio::Schema do
  describe "simple schemas" do
    it "validates string schema" do
      email_schema = Class.new(Raggio::Schema::Base) do
        string(format: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i)
      end

      expect(email_schema.decode("test@example.com")).to eq("test@example.com")
      expect { email_schema.decode("invalid-email") }.to raise_error(Raggio::Schema::ValidationError)
    end

    it "validates string with min/max constraints" do
      country_code_schema = Class.new(Raggio::Schema::Base) do
        string(min: 2, max: 2)
      end

      expect(country_code_schema.decode("US")).to eq("US")
      expect { country_code_schema.decode("USA") }.to raise_error(Raggio::Schema::ValidationError)
      expect { country_code_schema.decode("U") }.to raise_error(Raggio::Schema::ValidationError)
    end

    it "validates string with in constraint" do
      mass_unit_schema = Class.new(Raggio::Schema::Base) do
        literal %w[KG LB]
      end

      expect(mass_unit_schema.decode("KG")).to eq("KG")
      expect(mass_unit_schema.decode("LB")).to eq("LB")
      expect { mass_unit_schema.decode("G") }.to raise_error(Raggio::Schema::ValidationError)
    end

    it "validates number with greater_than constraint" do
      positive_number_schema = Class.new(Raggio::Schema::Base) do
        number(greater_than: 0)
      end

      expect(positive_number_schema.decode(5)).to eq(5)
      expect(positive_number_schema.decode(0.1)).to eq(0.1)
      expect { positive_number_schema.decode(0) }.to raise_error(Raggio::Schema::ValidationError)
      expect { positive_number_schema.decode(-1) }.to raise_error(Raggio::Schema::ValidationError)
    end

    it "validates boolean" do
      boolean_schema = Class.new(Raggio::Schema::Base) do
        boolean
      end

      expect(boolean_schema.decode(true)).to eq(true)
      expect(boolean_schema.decode(false)).to eq(false)
      expect { boolean_schema.decode("true") }.to raise_error(Raggio::Schema::ValidationError)
    end
  end

  describe "composite schemas" do
    it "validates struct schema" do
      address_schema = Class.new(Raggio::Schema::Base) do
        struct({
          country_code: string(min: 2, max: 2),
          zip_code: string
        })
      end

      valid_data = {
        country_code: "US",
        zip_code: "12345"
      }

      result = address_schema.decode(valid_data)
      expect(result[:country_code]).to eq("US")
      expect(result[:zip_code]).to eq("12345")
    end

    it "rejects invalid struct data" do
      address_schema = Class.new(Raggio::Schema::Base) do
        struct({
          country_code: string(min: 2, max: 2),
          zip_code: string
        })
      end

      invalid_data = {
        country_code: "USA",
        zip_code: "12345"
      }

      expect { address_schema.decode(invalid_data) }.to raise_error(Raggio::Schema::ValidationError)
    end

    it "validates nested structs" do
      address_schema = Class.new(Raggio::Schema::Base) do
        struct({
          country_code: string(min: 2, max: 2),
          zip_code: string
        })
      end

      request_schema = Class.new(Raggio::Schema::Base) do
        addr_schema = address_schema
        struct({
          address_from: addr_schema,
          address_to: addr_schema,
          parcel: struct({
            height: number(greater_than: 0),
            length: number(greater_than: 0),
            weight: number(greater_than: 0),
            width: number(greater_than: 0),
            mass_unit: literal(%w[KG LB]),
            currency: literal(%w[MXN USD]),
            distance_unit: literal(%w[CM IN])
          })
        })
      end

      valid_data = {
        address_from: {country_code: "US", zip_code: "12345"},
        address_to: {country_code: "MX", zip_code: "54321"},
        parcel: {
          height: 10,
          length: 20,
          weight: 5,
          width: 15,
          mass_unit: "KG",
          currency: "USD",
          distance_unit: "CM"
        }
      }

      result = request_schema.decode(valid_data)
      expect(result[:address_from][:country_code]).to eq("US")
      expect(result[:parcel][:mass_unit]).to eq("KG")
    end
  end

  describe "arrays" do
    it "validates array of schemas" do
      rate_schema = Class.new(Raggio::Schema::Base) do
        struct({
          service: string,
          currency: string,
          uuid: string,
          zone: optional(string),
          carrier: string,
          cancellable: optional(boolean),
          total_amount: transform(string, BigDecimal,
            decode: ->(x) { BigDecimal(x.to_s) if x },
            encode: ->(x) { x&.to_f }),
          additional_fees: optional(array(string)),
          shipping_type: optional(string),
          lead_time: optional(string)
        })
      end

      rates_response_schema = Class.new(Raggio::Schema::Base) do
        r_schema = rate_schema
        struct({
          data: array(r_schema)
        })
      end
      valid_data = {
        data: [
          {
            service: "Express",
            currency: "USD",
            uuid: "123-456",
            zone: "Zone1",
            carrier: "FedEx",
            cancellable: true,
            total_amount: "99.99",
            additional_fees: %w[handling insurance],
            shipping_type: "air",
            lead_time: "2-3 days"
          },
          {
            service: "Standard",
            currency: "USD",
            uuid: "789-012",
            carrier: "UPS",
            total_amount: "49.99"
          }
        ]
      }

      result = rates_response_schema.decode(valid_data)
      expect(result[:data].length).to eq(2)
      expect(result[:data][0][:service]).to eq("Express")
      expect(result[:data][0][:total_amount]).to be_a(BigDecimal)
      expect(result[:data][0][:total_amount]).to eq(BigDecimal("99.99"))
      expect(result[:data][1][:zone]).to be_nil
    end
  end

  describe "optional fields" do
    it "allows nil for optional fields" do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          required_field: string,
          optional_field: optional(string)
        })
      end

      valid_data = {
        required_field: "test"
      }

      result = schema.decode(valid_data)
      expect(result[:required_field]).to eq("test")
      expect(result[:optional_field]).to be_nil
    end

    it "rejects nil for required fields" do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          required_field: string
        })
      end

      invalid_data = {}

      expect { schema.decode(invalid_data) }.to raise_error(Raggio::Schema::ValidationError)
    end
  end

  describe "transform" do
    it "transforms values on decode and encode" do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          amount: transform(string, BigDecimal,
            decode: ->(x) { BigDecimal(x.to_s) if x },
            encode: ->(x) { x&.to_f })
        })
      end

      decoded = schema.decode({amount: "123.45"})
      expect(decoded[:amount]).to be_a(BigDecimal)
      expect(decoded[:amount]).to eq(BigDecimal("123.45"))

      encoded = schema.encode({amount: BigDecimal("123.45")})
      expect(encoded[:amount]).to eq(123.45)
    end
  end

  describe "array constraints" do
    it "validates min constraint" do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, min: 2)
      end

      expect(schema.decode(%w[a b])).to eq(%w[a b])
      expect(schema.decode(%w[a b c])).to eq(%w[a b c])
      expect { schema.decode(["a"]) }.to raise_error(Raggio::Schema::ValidationError, /at least 2/)
    end

    it "validates max constraint" do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, max: 2)
      end

      expect(schema.decode(%w[a b])).to eq(%w[a b])
      expect(schema.decode(["a"])).to eq(["a"])
      expect { schema.decode(%w[a b c]) }.to raise_error(Raggio::Schema::ValidationError, /at most 2/)
    end

    it "validates length constraint" do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, length: 2)
      end

      expect(schema.decode(%w[a b])).to eq(%w[a b])
      expect { schema.decode(["a"]) }.to raise_error(Raggio::Schema::ValidationError, /exactly 2/)
      expect { schema.decode(%w[a b c]) }.to raise_error(Raggio::Schema::ValidationError, /exactly 2/)
    end

    it "validates unique constraint" do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, unique: true)
      end

      expect(schema.decode(%w[a b c])).to eq(%w[a b c])
      expect { schema.decode(%w[a b a]) }.to raise_error(Raggio::Schema::ValidationError, /must be unique/)
    end

    it "combines multiple constraints" do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, min: 2, max: 4, unique: true)
      end

      expect(schema.decode(%w[a b])).to eq(%w[a b])
      expect { schema.decode(["a"]) }.to raise_error(Raggio::Schema::ValidationError)
      expect { schema.decode(%w[a b c d e]) }.to raise_error(Raggio::Schema::ValidationError)
      expect { schema.decode(%w[a b a]) }.to raise_error(Raggio::Schema::ValidationError)
    end
  end

  describe "struct constraints" do
    it "rejects extra keys by default (extra_keys: :reject)" do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string
        })
      end

      expect(schema.decode({name: "John"})).to eq({name: "John"})
      expect do
        schema.decode({name: "John", age: 30})
      end.to raise_error(Raggio::Schema::ValidationError, /Unexpected keys/)
    end

    it "allows but excludes extra keys with extra_keys: :allow" do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string
        }, extra_keys: :allow)
      end

      result = schema.decode({name: "John", age: 30, city: "NYC"})
      expect(result[:name]).to eq("John")
      expect(result[:age]).to be_nil
      expect(result[:city]).to be_nil
      expect(result.keys).to eq([:name])
    end

    it "includes extra keys with extra_keys: :include" do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string
        }, extra_keys: :include)
      end

      result = schema.decode({name: "John", age: 30, city: "NYC"})
      expect(result[:name]).to eq("John")
      expect(result[:age]).to eq(30)
      expect(result[:city]).to eq("NYC")
    end

    it "validates required fields (non-optional)" do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string,
          email: optional(string),
          age: number
        })
      end

      expect(schema.decode({name: "John", age: 30})).to be_a(Hash)
      expect(schema.decode({name: "John", age: 30})[:email]).to be_nil
    end

    it "allows nil for optional fields" do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string,
          email: optional(string),
          phone: optional(string)
        })
      end

      result = schema.decode({name: "John"})
      expect(result[:name]).to eq("John")
      expect(result[:email]).to be_nil
      expect(result[:phone]).to be_nil
    end
  end
end

describe "Literal" do
  it "validates string literals" do
    class Status < Raggio::Schema::Base
      literal %w[pending approved rejected]
    end

    expect(Status.decode("pending")).to eq("pending")
    expect(Status.decode("approved")).to eq("approved")
    expect(Status.decode("rejected")).to eq("rejected")

    expect { Status.decode("unknown") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected one of \["pending", "approved", "rejected"\]/
    )
  end

  it "validates number literals" do
    class Priority < Raggio::Schema::Base
      literal 1, 2, 3
    end

    expect(Priority.decode(1)).to eq(1)
    expect(Priority.decode(2)).to eq(2)
    expect(Priority.decode(3)).to eq(3)

    expect { Priority.decode(5) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected one of \[1, 2, 3\]/
    )
  end

  it "validates boolean literals" do
    class Toggle < Raggio::Schema::Base
      literal true, false
    end

    expect(Toggle.decode(true)).to eq(true)
    expect(Toggle.decode(false)).to eq(false)

    expect { Toggle.decode("true") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected one of \[true, false\]/
    )
  end

  it "works within structs" do
    class UserWithStatus < Raggio::Schema::Base
      struct({
        name: string,
        status: literal(%w[active inactive banned])
      })
    end

    result = UserWithStatus.decode({
      name: "Alice",
      status: "active"
    })

    expect(result[:name]).to eq("Alice")
    expect(result[:status]).to eq("active")

    expect do
      UserWithStatus.decode({
        name: "Bob",
        status: "unknown"
      })
    end.to raise_error(Raggio::Schema::ValidationError)
  end

  it "validates single literal value" do
    class Constant < Raggio::Schema::Base
      literal "SUCCESS"
    end

    expect(Constant.decode("SUCCESS")).to eq("SUCCESS")
    expect { Constant.decode("FAILURE") }.to raise_error(
      Raggio::Schema::ValidationError
    )
  end

  it "validates literal with array syntax" do
    class HttpMethod < Raggio::Schema::Base
      literal %w[GET POST PUT DELETE]
    end

    expect(HttpMethod.decode("GET")).to eq("GET")
    expect(HttpMethod.decode("POST")).to eq("POST")
    expect { HttpMethod.decode("PATCH") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected one of \["GET", "POST", "PUT", "DELETE"\]/
    )
  end
end

describe "Union" do
  it "validates string or number" do
    class StringOrNumber < Raggio::Schema::Base
      union(string, number)
    end

    expect(StringOrNumber.decode("hello")).to eq("hello")
    expect(StringOrNumber.decode(42)).to eq(42)

    expect { StringOrNumber.decode(true) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Union decoding failed/
    )
  end

  it "validates union of literals" do
    class Status < Raggio::Schema::Base
      union(
        literal("pending"),
        literal("approved"),
        literal("rejected")
      )
    end

    expect(Status.decode("pending")).to eq("pending")
    expect(Status.decode("approved")).to eq("approved")
    expect(Status.decode("rejected")).to eq("rejected")

    expect { Status.decode("unknown") }.to raise_error(Raggio::Schema::ValidationError)
  end

  it "validates union of structs" do
    class Circle < Raggio::Schema::Base
      struct({
        kind: literal("circle"),
        radius: number
      })
    end

    class Square < Raggio::Schema::Base
      struct({
        kind: literal("square"),
        side_length: number
      })
    end

    class Shape < Raggio::Schema::Base
      union(Circle.schema_type, Square.schema_type)
    end

    circle = Shape.decode({kind: "circle", radius: 10})
    expect(circle[:kind]).to eq("circle")
    expect(circle[:radius]).to eq(10)

    square = Shape.decode({kind: "square", side_length: 5})
    expect(square[:kind]).to eq("square")
    expect(square[:side_length]).to eq(5)

    expect do
      Shape.decode({kind: "triangle", base: 5})
    end.to raise_error(Raggio::Schema::ValidationError)
  end

  it "tries members in order" do
    class OverlappingUnion < Raggio::Schema::Base
      union(
        struct({a: string, b: number}),
        struct({a: string})
      )
    end

    result = OverlappingUnion.decode({a: "test", b: 42})
    expect(result).to eq({a: "test", b: 42})

    result = OverlappingUnion.decode({a: "test"})
    expect(result).to eq({a: "test"})
  end
end

describe "Tuple" do
  it "validates fixed-length tuples" do
    class Point < Raggio::Schema::Base
      tuple(number, number)
    end

    expect(Point.decode([10, 20])).to eq([10, 20])
    expect(Point.decode([0, 0])).to eq([0, 0])
  end

  it "validates tuples with different types" do
    class Person < Raggio::Schema::Base
      tuple(string, number, boolean)
    end

    result = Person.decode(["Alice", 30, true])
    expect(result).to eq(["Alice", 30, true])
  end

    it "rejects tuples with wrong length" do
      class Pair < Raggio::Schema::Base
        tuple(string, number)
      end

      expect { Pair.decode(["a"]) }.to raise_error(
        Raggio::Schema::ValidationError,
        /Expected exactly 2 elements, got 1/
      )

      expect { Pair.decode(["a", 1, true]) }.to raise_error(
        Raggio::Schema::ValidationError,
        /Expected exactly 2 elements, got 3/
      )
    end

  it "validates element types" do
    class Coordinates < Raggio::Schema::Base
      tuple(number, number)
    end

    expect { Coordinates.decode(["not a number", 20]) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Tuple element at index 0/
    )

    expect { Coordinates.decode([10, "not a number"]) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Tuple element at index 1/
    )
  end

  it "works with nested schemas" do
    class Address < Raggio::Schema::Base
      struct({
        street: string,
        city: string
      })
    end

    class PersonWithAddress < Raggio::Schema::Base
      tuple(string, number, Address)
    end

    result = PersonWithAddress.decode([
      "Bob",
      25,
      {street: "123 Main St", city: "NYC"}
    ])

    expect(result[0]).to eq("Bob")
    expect(result[1]).to eq(25)
    expect(result[2]).to eq({street: "123 Main St", city: "NYC"})
  end

  it "encodes tuples correctly" do
    class RGB < Raggio::Schema::Base
      tuple(number, number, number)
    end

    encoded = RGB.encode([255, 128, 0])
    expect(encoded).to eq([255, 128, 0])
  end
end

describe "Record" do
  it "validates basic record with string keys and number values" do
    class Scores < Raggio::Schema::Base
      record(key: string, value: number)
    end

    result = Scores.decode({"alice" => 95, "bob" => 87})
    expect(result).to eq({"alice" => 95, "bob" => 87})
  end

  it "accepts symbol keys and converts them to strings" do
    class Config < Raggio::Schema::Base
      record(key: string, value: string)
    end

    result = Config.decode({port: "3000", host: "localhost"})
    expect(result).to eq({"port" => "3000", "host" => "localhost"})
  end

  it "validates value types" do
    class Inventory < Raggio::Schema::Base
      record(key: string, value: number)
    end

    expect { Inventory.decode({"apples" => "not a number"}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Invalid value for key "apples"/
    )
  end

  it "validates key types" do
    class NumberMap < Raggio::Schema::Base
      record(key: string, value: boolean)
    end

    expect { NumberMap.decode({123 => true}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Invalid key 123/
    )
  end

  it "rejects non-hash values" do
    class Map < Raggio::Schema::Base
      record(key: string, value: string)
    end

    expect { Map.decode("not a hash") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected hash, got String/
    )
  end

  it "works with nested schemas as values" do
    class Person < Raggio::Schema::Base
      struct({name: string, age: number})
    end

    class People < Raggio::Schema::Base
      record(key: string, value: Person)
    end

    result = People.decode({
      "alice" => {name: "Alice", age: 30},
      "bob" => {name: "Bob", age: 25}
    })

    expect(result["alice"]).to eq({name: "Alice", age: 30})
    expect(result["bob"]).to eq({name: "Bob", age: 25})
  end

  it "validates nested schema values" do
    class Item < Raggio::Schema::Base
      struct({price: number, quantity: number})
    end

    class Cart < Raggio::Schema::Base
      record(key: string, value: Item)
    end

    expect { Cart.decode({"item1" => {price: "invalid", quantity: 5}}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Invalid value for key "item1"/
    )
  end

  it "encodes records correctly" do
    class Metadata < Raggio::Schema::Base
      record(key: string, value: number)
    end

    encoded = Metadata.encode({"version" => 1, "count" => 42})
    expect(encoded).to eq({"version" => 1, "count" => 42})
  end

  it "handles empty hashes" do
    class EmptyMap < Raggio::Schema::Base
      record(key: string, value: string)
    end

    result = EmptyMap.decode({})
    expect(result).to eq({})
  end
end

describe "Symbol" do
  it "validates symbols" do
    class Status < Raggio::Schema::Base
      symbol
    end

    result = Status.decode(:pending)
    expect(result).to eq(:pending)
  end

  it "rejects non-symbols" do
    class Status < Raggio::Schema::Base
      symbol
    end

    expect { Status.decode("pending") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected symbol, got String/
    )
  end
end

describe "Null" do
  it "validates nil values" do
    class OnlyNull < Raggio::Schema::Base
      null
    end

    result = OnlyNull.decode(nil)
    expect(result).to eq(nil)
  end

  it "rejects non-nil values" do
    class OnlyNull < Raggio::Schema::Base
      null
    end

    expect { OnlyNull.decode("not nil") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected nil, got String/
    )
  end
end

describe "Nullable" do
  it "accepts value or nil" do
    class NullableString < Raggio::Schema::Base
      nullable(string)
    end

    expect(NullableString.decode("hello")).to eq("hello")
    expect(NullableString.decode(nil)).to eq(nil)
  end

  it "rejects invalid values" do
    class NullableNumber < Raggio::Schema::Base
      nullable(number)
    end

    expect { NullableNumber.decode("not a number") }.to raise_error(
      Raggio::Schema::ValidationError
    )
  end

  it "works in structs" do
    class User < Raggio::Schema::Base
      struct({
        name: string,
        email: nullable(string)
      })
    end

    result1 = User.decode({name: "Alice", email: "alice@example.com"})
    expect(result1).to eq({name: "Alice", email: "alice@example.com"})

    result2 = User.decode({name: "Bob", email: nil})
    expect(result2).to eq({name: "Bob", email: nil})
  end
end

describe "Optional vs Nullable" do
  it "optional allows missing keys, nullable allows nil values" do
    class Config < Raggio::Schema::Base
      struct({
        required: string,
        nullable_field: nullable(string),
        optional_field: optional(string)
      })
    end

    expect(Config.decode({required: "hi", nullable_field: nil, optional_field: "opt"})).to eq(
      {required: "hi", nullable_field: nil, optional_field: "opt"}
    )

    expect(Config.decode({required: "hi", nullable_field: nil})).to eq(
      {required: "hi", nullable_field: nil}
    )

    expect(Config.decode({required: "hi", nullable_field: "val"})).to eq(
      {required: "hi", nullable_field: "val"}
    )

    expect { Config.decode({required: "hi"}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Field 'nullable_field' is required/
    )
  end
end
