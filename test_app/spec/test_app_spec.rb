# frozen_string_literal: true

RSpec.describe TestApp do
  let(:user) do
    described_class::User.new(
      created_at: Time.utc(2021, 12, 25, 5),
      name: described_class::Name.new('John', 'Doe'),
      date_of_birth: Date.new(1990, 6, 6),
      num_friends: 42
    )
  end

  it 'works' do
    expect(user).to be_a(described_class::User)
  end
end
