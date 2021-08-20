# frozen_string_literal: true

require 'snapshoot/rspec'

RSpec.describe Snapshoot do
  include Snapshoot

  it 'can fill in a basic snapshot' do
    expect(2 + 2).to match_snapshot
  end
end
