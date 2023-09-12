# Snapshoot

This is a little gem I put together that does some basic snapshot testing for RSpec tests.

For example, you can start with a test file like this:

```ruby
# frozen_string_literal: true

require 'snapshoot/rspec'

RSpec.describe TestApp do
  include Snapshoot

  let(:user) do
    described_class::User.new(
      created_at:    Time.utc(2021, 12, 25, 5),
      name:          described_class::Name.new('John', 'Doe'),
      date_of_birth: Date.new(1990, 6, 6),
      num_friends:   42
    )
  end

  it 'can snapshot num_friends' do
    expect(user.num_friends).to match_snapshot
  end

  it 'can snapshot date_of_birth' do
    expect(user.date_of_birth).to match_snapshot
  end

  it 'can snapshot the serialization' do
    expect(user.serialize).to match_snapshot
  end

  it 'is a user object' do
    expect(user).to match_snapshot
  end
end
```

and then after running the tests, the file is automatically updated like so:

```ruby
# frozen_string_literal: true

require 'snapshoot/rspec'

RSpec.describe TestApp do
  include Snapshoot

  let(:user) do
    described_class::User.new(
      created_at:    Time.utc(2021, 12, 25, 5),
      name:          described_class::Name.new('John', 'Doe'),
      date_of_birth: Date.new(1990, 6, 6),
      num_friends:   42
    )
  end

  it 'can snapshot num_friends' do
    expect(user.num_friends).to match_snapshot(42)
  end

  it 'can snapshot date_of_birth' do
    expect(user.date_of_birth).to match_snapshot(Date.new(1990, 6, 6))
  end

  it 'can snapshot the serialization' do
    expect(user.serialize).to match_snapshot(
      created_at:    Time.new(2021, 12, 25, 5, 0, 0, '+00:00'),
      first_name:    'John',
      last_name:     'Doe',
      date_of_birth: Date.new(1990, 6, 6),
      num_friends:   42
    )
  end

  it 'is a user object' do
    expect(user).to match_snapshot(
      TestApp::User.new(
        name:          TestApp::Name.new('John', 'Doe'),
        created_at:    Time.new(2021, 12, 25, 5, 0, 0, '+00:00'),
        date_of_birth: Date.new(1990, 6, 6),
        num_friends:   42
      )
    )
  end
end
```

## Should I use this?

Almost definitely not. I basically got this little side project to a state where it is useful for me. I wanted to make
it more "production ready" but I never got around to it. I still use it from time to time though so if you're curious
you could at the very least try and read the code. I promise nothing though and I have no intention to maintain this for
anything beyond personal use.

