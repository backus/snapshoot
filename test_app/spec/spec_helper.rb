# frozen_string_literal: true

require 'snapshoot'
require 'snapshoot/rspec'

require 'pry'
require 'pry-byebug'

RSpec.configure do |config|
  # Forbid RSpec from monkey patching any of our objects
  config.disable_monkey_patching!

  # We should address configuration warnings when we upgrade
  config.raise_errors_for_deprecations!
end
