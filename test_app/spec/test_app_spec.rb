# frozen_string_literal: true

require 'snapshoot/rspec'

RSpec.describe TestApp do
  include Snapshoot

  let(:user) do
    described_class::User.new(
      created_at: Time.utc(2021, 12, 25, 5),
      name: described_class::Name.new('John', 'Doe'),
      date_of_birth: Date.new(1990, 6, 6),
      num_friends: 42
    )
  end

  it 'is a user (sanity check)' do
    expect(user).to be_a(described_class::User)
  end

  it 'can snapshot num_friends' do
    expect(user.num_friends).to match_snapshot
  end

  it 'can snapshot date_of_birth' do
    expect(user.date_of_birth).to match_snapshot
  end
end
