# frozen_string_literal: true

require 'open3'

module SnapshootSpec
  class Shell
    include Anima.new(:stdout, :stderr, :status)

    def self.run(command)
      stdout, stderr, status = Open3.capture3(command)

      new(
        status: status,
        stdout: stdout,
        stderr: stderr
      )
    end

    def success?
      status.success?
    end

    def no_output?
      stdout.empty? && stderr.empty?
    end

    def outputs
      <<~OUTPUTS
        STDOUT:

        #{stdout}

        STDERR:

        #{stderr}
      OUTPUTS
    end
  end

  class Diff
    include Concord.new(:output)

    ignored_line_starters = [
      'diff --git',
      'index ',
      '--- ',
      '+++ ',
      '@@ '
    ]

    IGNORED_LINES = /\A#{Regexp.union(ignored_line_starters)}/.freeze

    def simple
      output
        .split("\n")
        .reject { |line| IGNORED_LINES.match?(line) }
        .map { |line| /\A\s*\z/.match?(line) ? '' : line } # Ensure whitespace only lines are just \n
        .join("\n")
    end
  end

  class TestApp
    def self.root
      ROOT.join('test_app')
    end

    def self.in_dir(&blk)
      Dir.chdir(root.to_s, &blk)
    end

    def assert_pristine!
      return if pristine?

      system("git status #{test_app_dir}")
      puts

      raise "Expected #{test_app_dir}'s git status to be pristine, but uncommitted changes were found"
    end

    def pristine?
      unstaged_pristine? && staged_pristine? && untracked_pristine?
    end

    def revert_changes
      revert = Shell.run("git restore #{test_app_dir}")
      unless revert.success?
        raise "Revert command was unsuccessful? (#{revert.status}) #{revert.outputs}"
      end

      unless pristine?
        puts 'test_app not pristine after reverting changes?'
        assert_pristine!
      end
    end

    def spec_diff
      diff = Shell.run("git diff -U2 --no-color #{test_app_dir.join('spec')}")
      raise 'Diff exit code was not zero?' unless diff.success?

      Diff.new(diff.stdout).simple
    end

    private

    def test_app_relative_path
      test_app_dir.relative_path_from(SnapshootSpec::ROOT).to_s
    end

    def test_app_dir
      SnapshootSpec::ROOT.join('test_app')
    end

    def unstaged_pristine?
      exit_code("git diff --quiet --exit-code #{test_app_dir}")
    end

    def staged_pristine?
      exit_code("git diff --quiet --exit-code --cached #{test_app_dir}")
    end

    def untracked_pristine?
      Shell
        .run("git ls-files --exclude-standard --others #{test_app_dir}")
        .no_output?
    end

    def exit_code(command)
      Shell.run(command).success?
    end
  end
end

RSpec.describe 'Snapshoot test app' do
  before(:all) do
    SnapshootSpec::TestApp.new.assert_pristine!
  end

  around do |example|
    SnapshootSpec::TestApp.in_dir do
      example.run
    end
  end

  let(:test_app) do
    SnapshootSpec::TestApp.new
  end

  def temporary_changes
    yield

    test_app.revert_changes
  end

  def run_test_app_specs
    SnapshootSpec::Shell.run('bundle exec rspec')
  end

  fit 'injects snapshots into tests' do
    temporary_changes do
      result = run_test_app_specs

      expect(result.success?).to be(true), result.outputs
      expect(test_app.spec_diff).to eql(<<~DIFF.chomp)

           it 'can snapshot num_friends' do
        -    expect(user.num_friends).to match_snapshot
        +    expect(user.num_friends).to match_snapshot(42)
           end

           it 'can snapshot date_of_birth' do
        -    expect(user.date_of_birth).to match_snapshot
        +    expect(user.date_of_birth).to match_snapshot(Date.new(1990, 6, 6))
           end

           it 'can snapshot the serialization' do
        -    expect(user.serialize).to match_snapshot
        +    expect(user.serialize).to match_snapshot({ created_at: Time.new(2021, 12, 25, 5, 0, 0, "+00:00"), first_name: "John", last_name: "Doe", date_of_birth: Date.new(1990, 6, 6), num_friends: 42 })
           end

           it 'is a user object' do
        -    expect(user).to match_snapshot
        +    expect(user).to match_snapshot(TestApp::User.new({ name: TestApp::Name.new("John", "Doe"), created_at: Time.new(2021, 12, 25, 5, 0, 0, "+00:00"), date_of_birth: Date.new(1990, 6, 6), num_friends: 42 }))
           end
         end
      DIFF
    end
  end

  it 'passes the test on the second run' do
    temporary_changes do
      first_run = run_test_app_specs

      expect(first_run.success?).to be(true),
                                    'Expected first run of test_app specs to pass but they did not'

      second_run = run_test_app_specs

      expect(second_run.success?).to be(true),
                                     'Expected second run of test_app specs to pass but they did not'
    end
  end
end
