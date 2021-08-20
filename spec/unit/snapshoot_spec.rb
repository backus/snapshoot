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

    lineno = 3
    actual_value = 4

    injector =
      described_class::Injector.new(source: source, lineno: lineno, actual_value: actual_value)

    expect(injector.inject).to eql(<<~RUBY)
      RSpec.describe 'example' do
        it 'can add 2 + 2' do
          expect(2 + 2).to match_snapshot(4)
        end
      end
    RUBY
  end
end
