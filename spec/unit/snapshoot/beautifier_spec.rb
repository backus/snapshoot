# frozen_string_literal: true

RSpec.describe Snapshoot::Beautifier do
  let(:ugly) do
    '{ created_at: Time.new(2021, 12, 25, 5, 0, 0, "+00:00"), first_name: "John", last_name: "Doe", date_of_birth: Date.new(1990, 6, 6), num_friends: 42 }'
  end

  let(:beautiful) do
    <<~RUBY.chomp
      {
        created_at:    Time.new(2021, 12, 25, 5, 0, 0, "+00:00"),
        first_name:    "John",
        last_name:     "Doe",
        date_of_birth: Date.new(1990, 6, 6),
        num_friends:   42
      }
    RUBY
  end

  it 'beautifies a long hash' do
    expect(described_class.new(ugly).format).to eql(beautiful)
  end
end
