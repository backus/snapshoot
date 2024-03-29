# frozen_string_literal: true

require 'snapshoot'
require 'rspec/expectations'
require 'concord'

module Snapshoot
  class Unset
    def inspect
      '(unset)'
    end
  end

  UNSET = Unset.new.freeze

  class Snapshot
    include Concord.new(:expected, :source_location)

    def matches?(actual)
      if unset?
        Snapshoot::Injector.from_spec(
          caller_location: source_location,
          actual_value:    actual
        ).schedule_change
      end
    end

    def unset?
      expected.equal?(UNSET)
    end
  end

  def match_snapshot(expected = UNSET)
    return RSpec::Matchers::BuiltIn::Eql.new(expected) unless expected.equal?(UNSET)

    source_location = caller_locations(1..1).first

    Snapshot.new(expected, source_location)
  end
end

RSpec.configure do |config|
  config.include(Snapshoot)

  config.after(:suite) do
    Snapshoot.scheduler.write_changes
  end
end
