# frozen_string_literal: true

RSpec.describe Snapshoot do
  let(:path) { instance_double(Pathname) }

  it 'can inject an integer into the snapshot matcher' do
    source = <<~RUBY
      RSpec.describe 'example' do
        it 'can add 2 + 2' do
          expect(2 + 2).to match_snapshot
        end
      end
    RUBY

    injector =
      described_class::Injector.new(path: path, source: source, injections: { 3 => 4 })

    expect(injector.rewrite).to eql(<<~RUBY)
      RSpec.describe 'example' do
        it 'can add 2 + 2' do
          expect(2 + 2).to match_snapshot(4)
        end
      end
    RUBY
  end

  fit 'can schedule a change' do
    source = <<~RUBY
      RSpec.describe 'example' do
        it 'can add 2 + 2' do
          expect(2 + 2).to match_snapshot
        end
      end
    RUBY

    allow(path).to receive(:expand_path).and_return(path)
    allow(path).to receive(:read).and_return(source)

    injector =
      described_class::Injector.new(path: path, source: source, injections: { 3 => 4 })

    injector.schedule_change
    expect(Snapshoot.scheduler).to be(nil)
  end

  it 'can inject multiple values into the snapshot' do
    source = <<~RUBY
      RSpec.describe 'example' do
        it 'can add 2 + 2' do
          expect(2 + 2).to match_snapshot
        end

        it 'can add 4 + 4' do
          expect(4 + 4).to match_snapshot
        end
      end
    RUBY

    line_actual_mapping = {
      3 => 4,
      7 => 8
    }

    injector =
      described_class::Injector.new(path: path, source: source, injections: line_actual_mapping)

    expect(injector.rewrite).to eql(<<~RUBY)
      RSpec.describe 'example' do
        it 'can add 2 + 2' do
          expect(2 + 2).to match_snapshot(4)
        end

        it 'can add 4 + 4' do
          expect(4 + 4).to match_snapshot(8)
        end
      end
    RUBY
  end
end
