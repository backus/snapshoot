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
    include Concord.new(:expected, :callers)

    def matches?(actual)
      binding.pry
    end
  end

  def match_snapshot(expected = UNSET)
    callers = caller_locations

    Snapshot.new(expected, callers)
  end
end
