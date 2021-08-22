# frozen_string_literal: true

require 'open3'

module SnapshootSpec
  class Shell
    include Anima.new(:stdout, :stderr, :status)

    def self.run(command)
      _stdin, stdout, stderr, process = Open3.popen3(command)

      new(
        status: process.value,
        stdout: stdout.read,
        stderr: stderr.read
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

  class TestApp
    def self.root
      ROOT.join('test_app')
    end

    def self.in_dir(&blk)
      Dir.chdir(root.to_s, &blk)
    end

    def assert_pristine!
      return if pristine?

      system("git status #{test_app_relative_path}")
      puts

      raise "Expected #{test_app_relative_path}'s git status to be pristine, but uncommitted changes were found"
    end

    def pristine?
      unstaged_pristine? && staged_pristine? && untracked_pristine?
    end

    private

    def test_app_relative_path
      test_app_dir.relative_path_from(SnapshootSpec::ROOT).to_s
    end

    def test_app_dir
      SnapshootSpec::ROOT.join('test_app')
    end

    def unstaged_pristine?
      exit_code("git diff --quiet --exit-code #{test_app_relative_path}")
    end

    def staged_pristine?
      exit_code("git diff --quiet --exit-code --cached #{test_app_relative_path}")
    end

    def untracked_pristine?
      Shell
        .run("git ls-files --exclude-standard --others #{test_app_relative_path}")
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

  it 'runs tests' do
    result = SnapshootSpec::Shell.run('bundle exec rspec')

    expect(result.success?).to be(true), result.outputs
  end
end
