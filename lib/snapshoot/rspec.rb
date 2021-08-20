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
      if unset?
        Snapshoot::Inliner.inline(actual, callers)
      else
        expected.eql?(actual)
      end
    end

    def unset?
      expected.equal?(UNSET)
    end
  end

  def match_snapshot(expected = UNSET)
    callers = caller_locations

    Snapshot.new(expected, callers)
  end
end
