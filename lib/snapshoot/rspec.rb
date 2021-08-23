# frozen_string_literal: true

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
        Snapshoot::Injector.from_spec(caller_location: source_location, actual_value: actual).inject
      else
        expected.eql?(actual)
      end
    end

    def unset?
      expected.equal?(UNSET)
    end
  end

  def match_snapshot(expected = UNSET)
    source_location = caller_locations(1..1).first

    Snapshot.new(expected, source_location)
  end
end
