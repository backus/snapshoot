# frozen_string_literal: true

RSpec.describe Snapshoot::Serializer do
  def serialize(value)
    Unparser.unparse(described_class.serialize(value))
  end

  it 'can serialize literals' do
    expect(serialize(42)).to eql('42')
    expect(serialize(2.5)).to eql('2.5')

    expect(serialize('Hello')).to eql('"Hello"')
    expect(serialize(:hello)).to eql(':hello')

    expect(serialize(true)).to eql('true')
    expect(serialize(false)).to eql('false')
    expect(serialize(nil)).to eql('nil')
  end

  it 'can serialize simple arrays' do
    value = [42, 2.5, 'hello', :hello, true, false, nil]

    expect(serialize(value)).to eql(
      '[42, 2.5, "hello", :hello, true, false, nil]'
    )
  end

  it 'can serialize simple hashes' do
    value = {
      'string' => 42,
      :symbol => 2.5,
      42 => nil
    }

    expect(serialize(value)).to eql(
      '{ "string" => 42, symbol: 2.5, 42 => nil }'
    )
  end

  it 'can serialize dates' do
    expect(serialize(Date.new(2020))).to eql(
      'Date.new(2020, 1, 1)'
    )
  end

  it 'can serialize a time' do
    expect(serialize(Time.utc(2021))).to eql(
      'Time.new(2021, 1, 1, 0, 0, 0, "+00:00")'
    )
  end
end
