# frozen_string_literal: true

RSpec.describe Snapshoot::Beautifier do
  def format(input)
    described_class.new(input).format
  end

  it 'beautifies a long hash' do
    ugly = '{ created_at: Time.new(2021, 12, 25, 5, 0, 0, "+00:00"), first_name: "John", last_name: "Doe", date_of_birth: Date.new(1990, 6, 6), num_friends: 42 }'
    beautiful = <<~RUBY.chomp
      {
        created_at:    Time.new(2021, 12, 25, 5, 0, 0, "+00:00"),
        first_name:    "John",
        last_name:     "Doe",
        date_of_birth: Date.new(1990, 6, 6),
        num_friends:   42
      }
    RUBY

    expect(format(ugly)).to eql(beautiful)
  end

  context 'removing curly braces from method sends' do
    it 'removes curly braces for a hash inside a send' do
      ugly = 'match_snapshot({ foo: 1 })'
      beautiful = 'match_snapshot(foo: 1)'

      expect(described_class.new(ugly).format).to eql(beautiful)
    end

    it 'behaves properly with multiline hashes' do
      expect(format('match_snapshot({ foo: 1, bar: 42_000_000 })')).to eql(<<~RUBY.chomp)
        match_snapshot(
          foo: 1,
          bar: 42_000_000
        )
      RUBY
    end
  end
end
