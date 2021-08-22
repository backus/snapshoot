# frozen_string_literal: true

require 'date'
require 'time'
require 'anima'
require 'concord'

module TestApp
  class User
    include Anima.new(:name, :created_at, :date_of_birth, :num_friends)

    def serialize
      {
        created_at: created_at,
        first_name: name.first,
        last_name: name.last,
        date_of_birth: date_of_birth,
        num_friends: num_friends
      }
    end
  end

  class Name
    include Concord::Public.new(:first, :last)
  end
end
