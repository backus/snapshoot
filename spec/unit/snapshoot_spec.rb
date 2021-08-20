# frozen_string_literal: true

require 'snapshoot'
require 'snapshoot/rspec'

RSpec.describe Snapshoot do
  include Snapshoot

  it 'can inject an integer into the snapshot matcher' do
    source = <<~RUBY
      RSpec.describe 'example' do
        it 'can add 2 + 2' do
          expect(2 + 2).to match_snapshot
        end
      end
    RUBY

    injector =
      described_class::Injector.new(source: source, injections: { 3 => 4 })

    expect(injector.inject).to eql(<<~RUBY)
      RSpec.describe 'example' do
        it 'can add 2 + 2' do
          expect(2 + 2).to match_snapshot(4)
        end
      end
    RUBY
  end

  it 'can inject multiple values into the snapshot' do
    source = <<~RUBY
      RSpec.describe 'example' do
        it 'can add 2 + 2' do
          expect(2 + 2).to match_snapshot
        end

        it 'can add 4 + 4' do
          expect(4 + 4).to match_snapshot
        end
      end
    RUBY

    line_actual_mapping = {
      3 => 4,
      7 => 8
    }

    injector =
      described_class::Injector.new(source: source, injections: line_actual_mapping)

    expect(injector.inject).to eql(<<~RUBY)
      RSpec.describe 'example' do
        it 'can add 2 + 2' do
          expect(2 + 2).to match_snapshot(4)
        end

        it 'can add 4 + 4' do
          expect(4 + 4).to match_snapshot(8)
        end
      end
    RUBY
  end
end
