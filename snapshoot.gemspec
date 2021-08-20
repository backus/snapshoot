# frozen_string_literal: true

require File.expand_path('lib/snapshoot/version', __dir__)

Gem::Specification.new do |spec|
  spec.name        = 'snapshoot'
  spec.version     = Snapshoot::VERSION
  spec.authors     = %w[John Backus]
  spec.email       = %w[johncbackus@gmail.com]

  spec.summary     = 'Inline snapshots for RSpec'
  spec.description = 'Automatically fill in test expectations with inline snapshots, like Jest'
  spec.homepage    = 'https://github.com/backus/snapshoot'

  spec.files         = `git ls-files`.split("\n")
  spec.require_paths = %w[lib]
  spec.executables   = %w[snapshoot]

  spec.add_dependency 'anima',    '~> 0.3'
  spec.add_dependency 'concord',  '~> 0.1'
  spec.add_dependency 'parser'
  spec.add_dependency 'rspec', '~> 3.4'
  spec.add_dependency 'unparser'
end
