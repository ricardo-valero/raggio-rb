require 'spec_helper'
require 'bigdecimal'

RSpec.describe Raggio::Schema do
  describe 'simple schemas' do
    it 'validates string schema' do
      email_schema = Class.new(Raggio::Schema::Base) do
        string(format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      end

      expect(email_schema.decode('test@example.com')).to eq('test@example.com')
      expect { email_schema.decode('invalid-email') }.to raise_error(Raggio::Schema::ValidationError)
    end

    it 'validates string with min/max constraints' do
      country_code_schema = Class.new(Raggio::Schema::Base) do
        string(min: 2, max: 2)
      end

      expect(country_code_schema.decode('US')).to eq('US')
      expect { country_code_schema.decode('USA') }.to raise_error(Raggio::Schema::ValidationError)
      expect { country_code_schema.decode('U') }.to raise_error(Raggio::Schema::ValidationError)
    end

    it 'validates string with in constraint' do
      mass_unit_schema = Class.new(Raggio::Schema::Base) do
        string(in: %w[KG LB])
      end

      expect(mass_unit_schema.decode('KG')).to eq('KG')
      expect(mass_unit_schema.decode('LB')).to eq('LB')
      expect { mass_unit_schema.decode('G') }.to raise_error(Raggio::Schema::ValidationError)
    end

    it 'validates number with greater_than constraint' do
      positive_number_schema = Class.new(Raggio::Schema::Base) do
        number(greater_than: 0)
      end

      expect(positive_number_schema.decode(5)).to eq(5)
      expect(positive_number_schema.decode(0.1)).to eq(0.1)
      expect { positive_number_schema.decode(0) }.to raise_error(Raggio::Schema::ValidationError)
      expect { positive_number_schema.decode(-1) }.to raise_error(Raggio::Schema::ValidationError)
    end

    it 'validates boolean' do
      boolean_schema = Class.new(Raggio::Schema::Base) do
        boolean
      end

      expect(boolean_schema.decode(true)).to eq(true)
      expect(boolean_schema.decode(false)).to eq(false)
      expect { boolean_schema.decode('true') }.to raise_error(Raggio::Schema::ValidationError)
    end
  end

  describe 'composite schemas' do
    it 'validates struct schema' do
      address_schema = Class.new(Raggio::Schema::Base) do
        struct({
          country_code: string(min: 2, max: 2),
          zip_code: string
        })
      end

      valid_data = {
        country_code: 'US',
        zip_code: '12345'
      }

      result = address_schema.decode(valid_data)
      expect(result[:country_code]).to eq('US')
      expect(result[:zip_code]).to eq('12345')
    end

    it 'rejects invalid struct data' do
      address_schema = Class.new(Raggio::Schema::Base) do
        struct({
          country_code: string(min: 2, max: 2),
          zip_code: string
        })
      end

      invalid_data = {
        country_code: 'USA',
        zip_code: '12345'
      }

      expect { address_schema.decode(invalid_data) }.to raise_error(Raggio::Schema::ValidationError)
    end

    it 'validates nested structs' do
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
            mass_unit: string(in: %w[KG LB]),
            currency: string(in: %w[MXN USD]),
            distance_unit: string(in: %w[CM IN])
          })
        })
      end

      valid_data = {
        address_from: { country_code: 'US', zip_code: '12345' },
        address_to: { country_code: 'MX', zip_code: '54321' },
        parcel: {
          height: 10,
          length: 20,
          weight: 5,
          width: 15,
          mass_unit: 'KG',
          currency: 'USD',
          distance_unit: 'CM'
        }
      }

      result = request_schema.decode(valid_data)
      expect(result[:address_from][:country_code]).to eq('US')
      expect(result[:parcel][:mass_unit]).to eq('KG')
    end
  end

  describe 'arrays' do
    it 'validates array of schemas' do
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
            service: 'Express',
            currency: 'USD',
            uuid: '123-456',
            zone: 'Zone1',
            carrier: 'FedEx',
            cancellable: true,
            total_amount: '99.99',
            additional_fees: ['handling', 'insurance'],
            shipping_type: 'air',
            lead_time: '2-3 days'
          },
          {
            service: 'Standard',
            currency: 'USD',
            uuid: '789-012',
            carrier: 'UPS',
            total_amount: '49.99'
          }
        ]
      }

      result = rates_response_schema.decode(valid_data)
      expect(result[:data].length).to eq(2)
      expect(result[:data][0][:service]).to eq('Express')
      expect(result[:data][0][:total_amount]).to be_a(BigDecimal)
      expect(result[:data][0][:total_amount]).to eq(BigDecimal('99.99'))
      expect(result[:data][1][:zone]).to be_nil
    end
  end

  describe 'optional fields' do
    it 'allows nil for optional fields' do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          required_field: string,
          optional_field: optional(string)
        })
      end

      valid_data = {
        required_field: 'test'
      }

      result = schema.decode(valid_data)
      expect(result[:required_field]).to eq('test')
      expect(result[:optional_field]).to be_nil
    end

    it 'rejects nil for required fields' do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          required_field: string
        })
      end

      invalid_data = {}

      expect { schema.decode(invalid_data) }.to raise_error(Raggio::Schema::ValidationError)
    end
  end

  describe 'transform' do
    it 'transforms values on decode and encode' do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          amount: transform(string, BigDecimal,
            decode: ->(x) { BigDecimal(x.to_s) if x },
            encode: ->(x) { x&.to_f })
        })
      end

      decoded = schema.decode({ amount: '123.45' })
      expect(decoded[:amount]).to be_a(BigDecimal)
      expect(decoded[:amount]).to eq(BigDecimal('123.45'))

      encoded = schema.encode({ amount: BigDecimal('123.45') })
      expect(encoded[:amount]).to eq(123.45)
    end
  end

  describe 'array constraints' do
    it 'validates min constraint' do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, min: 2)
      end

      expect(schema.decode(['a', 'b'])).to eq(['a', 'b'])
      expect(schema.decode(['a', 'b', 'c'])).to eq(['a', 'b', 'c'])
      expect { schema.decode(['a']) }.to raise_error(Raggio::Schema::ValidationError, /at least 2/)
    end

    it 'validates max constraint' do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, max: 2)
      end

      expect(schema.decode(['a', 'b'])).to eq(['a', 'b'])
      expect(schema.decode(['a'])).to eq(['a'])
      expect { schema.decode(['a', 'b', 'c']) }.to raise_error(Raggio::Schema::ValidationError, /at most 2/)
    end

    it 'validates length constraint' do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, length: 2)
      end

      expect(schema.decode(['a', 'b'])).to eq(['a', 'b'])
      expect { schema.decode(['a']) }.to raise_error(Raggio::Schema::ValidationError, /exactly 2/)
      expect { schema.decode(['a', 'b', 'c']) }.to raise_error(Raggio::Schema::ValidationError, /exactly 2/)
    end

    it 'validates unique constraint' do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, unique: true)
      end

      expect(schema.decode(['a', 'b', 'c'])).to eq(['a', 'b', 'c'])
      expect { schema.decode(['a', 'b', 'a']) }.to raise_error(Raggio::Schema::ValidationError, /must be unique/)
    end

    it 'combines multiple constraints' do
      schema = Class.new(Raggio::Schema::Base) do
        array(string, min: 2, max: 4, unique: true)
      end

      expect(schema.decode(['a', 'b'])).to eq(['a', 'b'])
      expect { schema.decode(['a']) }.to raise_error(Raggio::Schema::ValidationError)
      expect { schema.decode(['a', 'b', 'c', 'd', 'e']) }.to raise_error(Raggio::Schema::ValidationError)
      expect { schema.decode(['a', 'b', 'a']) }.to raise_error(Raggio::Schema::ValidationError)
    end
  end

  describe 'struct constraints' do
    it 'rejects extra keys by default (extra_keys: :reject)' do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string
        })
      end

      expect(schema.decode({ name: 'John' })).to eq({ name: 'John' })
      expect { schema.decode({ name: 'John', age: 30 }) }.to raise_error(Raggio::Schema::ValidationError, /Unexpected keys/)
    end

    it 'allows but excludes extra keys with extra_keys: :allow' do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string
        }, extra_keys: :allow)
      end

      result = schema.decode({ name: 'John', age: 30, city: 'NYC' })
      expect(result[:name]).to eq('John')
      expect(result[:age]).to be_nil
      expect(result[:city]).to be_nil
      expect(result.keys).to eq([:name])
    end

    it 'includes extra keys with extra_keys: :include' do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string
        }, extra_keys: :include)
      end

      result = schema.decode({ name: 'John', age: 30, city: 'NYC' })
      expect(result[:name]).to eq('John')
      expect(result[:age]).to eq(30)
      expect(result[:city]).to eq('NYC')
    end

    it 'validates required fields (non-optional)' do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string,
          email: optional(string),
          age: number
        })
      end

      expect(schema.decode({ name: 'John', age: 30 })).to be_a(Hash)
      expect(schema.decode({ name: 'John', age: 30 })[:email]).to be_nil
    end

    it 'allows nil for optional fields' do
      schema = Class.new(Raggio::Schema::Base) do
        struct({
          name: string,
          email: optional(string),
          phone: optional(string)
        })
      end

      result = schema.decode({ name: 'John' })
      expect(result[:name]).to eq('John')
      expect(result[:email]).to be_nil
      expect(result[:phone]).to be_nil
    end
  end
end
