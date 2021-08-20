# frozen_string_literal: true

source 'https://rubygems.org'

ruby File.read('.ruby-version').chomp

gemspec

group :test do
  gem 'rspec', '~> 3.10'
end

group :lint do
  gem 'rake' # sickill/rainbow#44
  gem 'rubocop', '~> 1.19.1'
  gem 'rubocop-rspec', '~> 2.4.0'
end
