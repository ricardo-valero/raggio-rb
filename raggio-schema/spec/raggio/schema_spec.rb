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
    status = Class.new(Raggio::Schema::Base) do
      literal %w[pending approved rejected]
    end

    expect(status.decode("pending")).to eq("pending")
    expect(status.decode("approved")).to eq("approved")
    expect(status.decode("rejected")).to eq("rejected")

    expect { status.decode("unknown") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected one of \["pending", "approved", "rejected"\]/
    )
  end

  it "validates number literals" do
    priority = Class.new(Raggio::Schema::Base) do
      literal 1, 2, 3
    end

    expect(priority.decode(1)).to eq(1)
    expect(priority.decode(2)).to eq(2)
    expect(priority.decode(3)).to eq(3)

    expect { priority.decode(5) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected one of \[1, 2, 3\]/
    )
  end

  it "validates boolean literals" do
    toggle = Class.new(Raggio::Schema::Base) do
      literal true, false
    end

    expect(toggle.decode(true)).to eq(true)
    expect(toggle.decode(false)).to eq(false)

    expect { toggle.decode("true") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected one of \[true, false\]/
    )
  end

  it "works within structs" do
    user_with_status = Class.new(Raggio::Schema::Base) do
      struct({
        name: string,
        status: literal(%w[active inactive banned])
      })
    end

    result = user_with_status.decode({
      name: "Alice",
      status: "active"
    })

    expect(result[:name]).to eq("Alice")
    expect(result[:status]).to eq("active")

    expect do
      user_with_status.decode({
        name: "Bob",
        status: "unknown"
      })
    end.to raise_error(Raggio::Schema::ValidationError)
  end

  it "validates single literal value" do
    constant = Class.new(Raggio::Schema::Base) do
      literal "SUCCESS"
    end

    expect(constant.decode("SUCCESS")).to eq("SUCCESS")
    expect { constant.decode("FAILURE") }.to raise_error(
      Raggio::Schema::ValidationError
    )
  end

  it "validates literal with array syntax" do
    http_method = Class.new(Raggio::Schema::Base) do
      literal %w[GET POST PUT DELETE]
    end

    expect(http_method.decode("GET")).to eq("GET")
    expect(http_method.decode("POST")).to eq("POST")
    expect { http_method.decode("PATCH") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected one of \["GET", "POST", "PUT", "DELETE"\]/
    )
  end
end

describe "Union" do
  it "validates string or number" do
    string_or_number = Class.new(Raggio::Schema::Base) do
      union(string, number)
    end

    expect(string_or_number.decode("hello")).to eq("hello")
    expect(string_or_number.decode(42)).to eq(42)

    expect { string_or_number.decode(true) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Union decoding failed/
    )
  end

  it "validates union of literals" do
    status = Class.new(Raggio::Schema::Base) do
      union(
        literal("pending"),
        literal("approved"),
        literal("rejected")
      )
    end

    expect(status.decode("pending")).to eq("pending")
    expect(status.decode("approved")).to eq("approved")
    expect(status.decode("rejected")).to eq("rejected")

    expect { status.decode("unknown") }.to raise_error(Raggio::Schema::ValidationError)
  end

  it "validates union of structs" do
    circle = Class.new(Raggio::Schema::Base) do
      struct({
        kind: literal("circle"),
        radius: number
      })
    end

    square = Class.new(Raggio::Schema::Base) do
      struct({
        kind: literal("square"),
        side_length: number
      })
    end

    shape = Class.new(Raggio::Schema::Base) do
      c = circle
      s = square
      union(c.schema_type, s.schema_type)
    end

    circle_result = shape.decode({kind: "circle", radius: 10})
    expect(circle_result[:kind]).to eq("circle")
    expect(circle_result[:radius]).to eq(10)

    square_result = shape.decode({kind: "square", side_length: 5})
    expect(square_result[:kind]).to eq("square")
    expect(square_result[:side_length]).to eq(5)

    expect do
      shape.decode({kind: "triangle", base: 5})
    end.to raise_error(Raggio::Schema::ValidationError)
  end

  it "tries members in order" do
    overlapping_union = Class.new(Raggio::Schema::Base) do
      union(
        struct({a: string, b: number}),
        struct({a: string})
      )
    end

    result = overlapping_union.decode({a: "test", b: 42})
    expect(result).to eq({a: "test", b: 42})

    result = overlapping_union.decode({a: "test"})
    expect(result).to eq({a: "test"})
  end
end

describe "Tuple" do
  it "validates fixed-length tuples" do
    point = Class.new(Raggio::Schema::Base) do
      tuple(number, number)
    end

    expect(point.decode([10, 20])).to eq([10, 20])
    expect(point.decode([0, 0])).to eq([0, 0])
  end

  it "validates tuples with different types" do
    person = Class.new(Raggio::Schema::Base) do
      tuple(string, number, boolean)
    end

    result = person.decode(["Alice", 30, true])
    expect(result).to eq(["Alice", 30, true])
  end

  it "rejects tuples with wrong length" do
    pair = Class.new(Raggio::Schema::Base) do
      tuple(string, number)
    end

    expect { pair.decode(["a"]) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected exactly 2 elements, got 1/
    )

    expect { pair.decode(["a", 1, true]) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected exactly 2 elements, got 3/
    )
  end

  it "validates element types" do
    coordinates = Class.new(Raggio::Schema::Base) do
      tuple(number, number)
    end

    expect { coordinates.decode(["not a number", 20]) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Tuple element at index 0/
    )

    expect { coordinates.decode([10, "not a number"]) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Tuple element at index 1/
    )
  end

  it "works with nested schemas" do
    address = Class.new(Raggio::Schema::Base) do
      struct({
        street: string,
        city: string
      })
    end

    person_with_address = Class.new(Raggio::Schema::Base) do
      addr = address
      tuple(string, number, addr)
    end

    result = person_with_address.decode([
      "Bob",
      25,
      {street: "123 Main St", city: "NYC"}
    ])

    expect(result[0]).to eq("Bob")
    expect(result[1]).to eq(25)
    expect(result[2]).to eq({street: "123 Main St", city: "NYC"})
  end

  it "encodes tuples correctly" do
    rgb = Class.new(Raggio::Schema::Base) do
      tuple(number, number, number)
    end

    encoded = rgb.encode([255, 128, 0])
    expect(encoded).to eq([255, 128, 0])
  end
end

describe "Record" do
  it "validates basic record with string keys and number values" do
    scores = Class.new(Raggio::Schema::Base) do
      record(key: string, value: number)
    end

    result = scores.decode({"alice" => 95, "bob" => 87})
    expect(result).to eq({"alice" => 95, "bob" => 87})
  end

  it "accepts symbol keys and converts them to strings" do
    config = Class.new(Raggio::Schema::Base) do
      record(key: string, value: string)
    end

    result = config.decode({port: "3000", host: "localhost"})
    expect(result).to eq({"port" => "3000", "host" => "localhost"})
  end

  it "validates value types" do
    inventory = Class.new(Raggio::Schema::Base) do
      record(key: string, value: number)
    end

    expect { inventory.decode({"apples" => "not a number"}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Invalid value for key "apples"/
    )
  end

  it "validates key types" do
    number_map = Class.new(Raggio::Schema::Base) do
      record(key: string, value: boolean)
    end

    expect { number_map.decode({123 => true}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Invalid key 123/
    )
  end

  it "rejects non-hash values" do
    map = Class.new(Raggio::Schema::Base) do
      record(key: string, value: string)
    end

    expect { map.decode("not a hash") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected hash, got String/
    )
  end

  it "works with nested schemas as values" do
    person = Class.new(Raggio::Schema::Base) do
      struct({name: string, age: number})
    end

    people = Class.new(Raggio::Schema::Base) do
      p = person
      record(key: string, value: p)
    end

    result = people.decode({
      "alice" => {name: "Alice", age: 30},
      "bob" => {name: "Bob", age: 25}
    })

    expect(result["alice"]).to eq({name: "Alice", age: 30})
    expect(result["bob"]).to eq({name: "Bob", age: 25})
  end

  it "validates nested schema values" do
    item = Class.new(Raggio::Schema::Base) do
      struct({price: number, quantity: number})
    end

    cart = Class.new(Raggio::Schema::Base) do
      i = item
      record(key: string, value: i)
    end

    expect { cart.decode({"item1" => {price: "invalid", quantity: 5}}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Invalid value for key "item1"/
    )
  end

  it "encodes records correctly" do
    metadata = Class.new(Raggio::Schema::Base) do
      record(key: string, value: number)
    end

    encoded = metadata.encode({"version" => 1, "count" => 42})
    expect(encoded).to eq({"version" => 1, "count" => 42})
  end

  it "handles empty hashes" do
    empty_map = Class.new(Raggio::Schema::Base) do
      record(key: string, value: string)
    end

    result = empty_map.decode({})
    expect(result).to eq({})
  end
end

describe "Symbol" do
  it "validates symbols" do
    status = Class.new(Raggio::Schema::Base) do
      symbol
    end

    result = status.decode(:pending)
    expect(result).to eq(:pending)
  end

  it "rejects non-symbols" do
    status = Class.new(Raggio::Schema::Base) do
      symbol
    end

    expect { status.decode("pending") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected symbol, got String/
    )
  end
end

describe "Null" do
  it "validates nil values" do
    only_null = Class.new(Raggio::Schema::Base) do
      null
    end

    result = only_null.decode(nil)
    expect(result).to eq(nil)
  end

  it "rejects non-nil values" do
    only_null = Class.new(Raggio::Schema::Base) do
      null
    end

    expect { only_null.decode("not nil") }.to raise_error(
      Raggio::Schema::ValidationError,
      /Expected nil, got String/
    )
  end
end

describe "Nullable" do
  it "accepts value or nil" do
    nullable_string = Class.new(Raggio::Schema::Base) do
      nullable(string)
    end

    expect(nullable_string.decode("hello")).to eq("hello")
    expect(nullable_string.decode(nil)).to eq(nil)
  end

  it "rejects invalid values" do
    nullable_number = Class.new(Raggio::Schema::Base) do
      nullable(number)
    end

    expect { nullable_number.decode("not a number") }.to raise_error(
      Raggio::Schema::ValidationError
    )
  end

  it "works in structs" do
    user = Class.new(Raggio::Schema::Base) do
      struct({
        name: string,
        email: nullable(string)
      })
    end

    result1 = user.decode({name: "Alice", email: "alice@example.com"})
    expect(result1).to eq({name: "Alice", email: "alice@example.com"})

    result2 = user.decode({name: "Bob", email: nil})
    expect(result2).to eq({name: "Bob", email: nil})
  end
end

describe "Optional vs Nullable" do
  it "optional allows missing keys, nullable allows nil values" do
    config = Class.new(Raggio::Schema::Base) do
      struct({
        required: string,
        nullable_field: nullable(string),
        optional_field: optional(string)
      })
    end

    expect(config.decode({required: "hi", nullable_field: nil, optional_field: "opt"})).to eq(
      {required: "hi", nullable_field: nil, optional_field: "opt"}
    )

    expect(config.decode({required: "hi", nullable_field: nil})).to eq(
      {required: "hi", nullable_field: nil}
    )

    expect(config.decode({required: "hi", nullable_field: "val"})).to eq(
      {required: "hi", nullable_field: "val"}
    )

    expect { config.decode({required: "hi"}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Field 'nullable_field' is required/
    )
  end
end

describe "Lazy/Recursive Types" do
  it "validates tree structures" do
    tree_node = Class.new(Raggio::Schema::Base) do
      struct({
        value: number,
        children: array(lazy(self))
      })
    end

    tree = tree_node.decode({
      value: 1,
      children: [
        {value: 2, children: []},
        {value: 3, children: [{value: 4, children: []}]}
      ]
    })

    expect(tree[:value]).to eq(1)
    expect(tree[:children].length).to eq(2)
    expect(tree[:children][0][:value]).to eq(2)
    expect(tree[:children][1][:children][0][:value]).to eq(4)
  end

  it "validates linked lists" do
    list_node = Class.new(Raggio::Schema::Base) do
      struct({
        value: string,
        next: nullable(lazy(self))
      })
    end

    list = list_node.decode({
      value: "first",
      next: {
        value: "second",
        next: {
          value: "third",
          next: nil
        }
      }
    })

    expect(list[:value]).to eq("first")
    expect(list[:next][:value]).to eq("second")
    expect(list[:next][:next][:value]).to eq("third")
    expect(list[:next][:next][:next]).to be_nil
  end

  it "validates category hierarchies" do
    category = Class.new(Raggio::Schema::Base) do
      struct({
        name: string,
        subcategories: optional(array(lazy(self)))
      })
    end

    data = category.decode({
      name: "Electronics",
      subcategories: [
        {name: "Phones"},
        {
          name: "Computers",
          subcategories: [
            {name: "Laptops"},
            {name: "Desktops"}
          ]
        }
      ]
    })

    expect(data[:name]).to eq("Electronics")
    expect(data[:subcategories].length).to eq(2)
    expect(data[:subcategories][1][:subcategories].length).to eq(2)
    expect(data[:subcategories][1][:subcategories][0][:name]).to eq("Laptops")
  end

  it "validates expression trees" do
    expr = Class.new(Raggio::Schema::Base) do
      union(
        struct({type: literal("literal"), value: number}),
        struct({
          type: literal("binary"),
          left: lazy(self),
          op: literal("+", "-", "*", "/"),
          right: lazy(self)
        })
      )
    end

    ast = expr.decode({
      type: "binary",
      left: {type: "literal", value: 5},
      op: "+",
      right: {
        type: "binary",
        left: {type: "literal", value: 3},
        op: "*",
        right: {type: "literal", value: 2}
      }
    })

    expect(ast[:type]).to eq("binary")
    expect(ast[:left][:value]).to eq(5)
    expect(ast[:right][:op]).to eq("*")
  end

  it "encodes recursive structures" do
    tree_node = Class.new(Raggio::Schema::Base) do
      struct({
        value: number,
        children: array(lazy(self))
      })
    end

    tree = {
      value: 1,
      children: [
        {value: 2, children: []}
      ]
    }

    encoded = tree_node.encode(tree)
    expect(encoded[:value]).to eq(1)
    expect(encoded[:children][0][:value]).to eq(2)
  end
end

describe "Default Values" do
  it "applies defaults for missing optional fields" do
    config = Class.new(Raggio::Schema::Base) do
      struct({
        name: string,
        port: optional(number, 3000),
        host: optional(string, "localhost")
      })
    end

    result = config.decode({name: "myapp"})
    expect(result[:name]).to eq("myapp")
    expect(result[:port]).to eq(3000)
    expect(result[:host]).to eq("localhost")
  end

  it "uses provided values over defaults" do
    config = Class.new(Raggio::Schema::Base) do
      struct({
        name: string,
        port: optional(number, 3000)
      })
    end

    result = config.decode({name: "myapp", port: 8080})
    expect(result[:name]).to eq("myapp")
    expect(result[:port]).to eq(8080)
  end

  it "applies defaults for complex types" do
    config = Class.new(Raggio::Schema::Base) do
      struct({
        name: string,
        tags: optional(array(string), []),
        debug: optional(boolean, false)
      })
    end

    result = config.decode({name: "myapp"})
    expect(result[:name]).to eq("myapp")
    expect(result[:tags]).to eq([])
    expect(result[:debug]).to eq(false)
  end

  it "validates default values at schema definition time" do
    expect {
      Class.new(Raggio::Schema::Base) do
        struct({
          port: optional(number(min: 10), 5)
        })
      end
    }.to raise_error(ArgumentError, /Invalid default value/)
  end

  it "allows valid defaults that satisfy constraints" do
    config = Class.new(Raggio::Schema::Base) do
      struct({
        port: optional(number(min: 1, max: 65535), 3000)
      })
    end

    result = config.decode({})
    expect(result[:port]).to eq(3000)
  end

  it "works with optional fields without defaults" do
    config = Class.new(Raggio::Schema::Base) do
      struct({
        name: string,
        port: optional(number, 3000),
        description: optional(string)
      })
    end

    result = config.decode({name: "myapp"})
    expect(result[:name]).to eq("myapp")
    expect(result[:port]).to eq(3000)
    expect(result.key?(:description)).to eq(false)
  end

  it "applies defaults for nested structs" do
    config = Class.new(Raggio::Schema::Base) do
      struct({
        name: string,
        server: optional(struct({
          host: string,
          port: number
        }), {host: "localhost", port: 3000})
      })
    end

    result = config.decode({name: "myapp"})
    expect(result[:name]).to eq("myapp")
    expect(result[:server][:host]).to eq("localhost")
    expect(result[:server][:port]).to eq(3000)
  end
end

describe "Discriminated Union" do
  it "validates based on discriminator field" do
    shape = Class.new(Raggio::Schema::Base) do
      discriminated_union(:type,
        circle: struct({type: literal("circle"), radius: number}),
        square: struct({type: literal("square"), side_length: number})
      )
    end

    circle = shape.decode({type: "circle", radius: 10})
    expect(circle[:type]).to eq("circle")
    expect(circle[:radius]).to eq(10)

    square = shape.decode({type: "square", side_length: 5})
    expect(square[:type]).to eq("square")
    expect(square[:side_length]).to eq(5)
  end

  it "rejects unknown discriminator values" do
    shape = Class.new(Raggio::Schema::Base) do
      discriminated_union(:type,
        circle: struct({type: literal("circle"), radius: number}),
        square: struct({type: literal("square"), side_length: number})
      )
    end

    expect { shape.decode({type: "triangle", base: 5}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Unknown discriminator value 'triangle'/
    )
  end

  it "rejects missing discriminator field" do
    shape = Class.new(Raggio::Schema::Base) do
      discriminated_union(:type,
        circle: struct({type: literal("circle"), radius: number})
      )
    end

    expect { shape.decode({radius: 10}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Missing discriminator field 'type'/
    )
  end

  it "works with symbol discriminator keys" do
    shape = Class.new(Raggio::Schema::Base) do
      discriminated_union(:type,
        circle: struct({type: literal("circle"), radius: number}),
        square: struct({type: literal("square"), side_length: number})
      )
    end

    result = shape.decode({type: "circle", radius: 15})
    expect(result[:type]).to eq("circle")
    expect(result[:radius]).to eq(15)
  end

  it "validates variant-specific fields" do
    shape = Class.new(Raggio::Schema::Base) do
      discriminated_union(:type,
        circle: struct({type: literal("circle"), radius: number(min: 0)}),
        square: struct({type: literal("square"), side_length: number(min: 0)})
      )
    end

    expect { shape.decode({type: "circle", radius: -5}) }.to raise_error(
      Raggio::Schema::ValidationError,
      /Number must be at least 0/
    )
  end

  it "works with API response pattern" do
    api_response = Class.new(Raggio::Schema::Base) do
      discriminated_union(:status,
        success: struct({status: literal("success"), data: record(key: string, value: string)}),
        error: struct({status: literal("error"), code: number, message: string})
      )
    end

    success = api_response.decode({status: "success", data: {"key" => "value"}})
    expect(success[:status]).to eq("success")
    expect(success[:data]).to eq({"key" => "value"})

    error = api_response.decode({status: "error", code: 404, message: "Not found"})
    expect(error[:status]).to eq("error")
    expect(error[:code]).to eq(404)
    expect(error[:message]).to eq("Not found")
  end

  it "encodes discriminated unions correctly" do
    shape = Class.new(Raggio::Schema::Base) do
      discriminated_union(:type,
        circle: struct({type: literal("circle"), radius: number}),
        square: struct({type: literal("square"), side_length: number})
      )
    end

    encoded = shape.encode({type: "circle", radius: 10})
    expect(encoded[:type]).to eq("circle")
    expect(encoded[:radius]).to eq(10)
  end

  it "validates that variants are struct types" do
    expect {
      Class.new(Raggio::Schema::Base) do
        discriminated_union(:type,
          circle: string
        )
      end
    }.to raise_error(ArgumentError, /must be a struct type/)
  end

  it "validates that variants include discriminator field" do
    expect {
      Class.new(Raggio::Schema::Base) do
        discriminated_union(:kind,
          circle: struct({type: literal("circle"), radius: number})
        )
      end
    }.to raise_error(ArgumentError, /must include discriminator field/)
  end

  it "validates that discriminator field is a literal" do
    expect {
      Class.new(Raggio::Schema::Base) do
        discriminated_union(:type,
          circle: struct({type: string, radius: number})
        )
      end
    }.to raise_error(ArgumentError, /must be a literal type/)
  end

  it "validates that literal matches variant key" do
    expect {
      Class.new(Raggio::Schema::Base) do
        discriminated_union(:type,
          circle: struct({type: literal("square"), radius: number})
        )
      end
    }.to raise_error(ArgumentError, /must include literal value 'circle'/)
  end
end
