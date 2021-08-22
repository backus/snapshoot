# frozen_string_literal: true

require 'open3'

module SnapshootSpec
  class TestApp
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
      shell("git ls-files --exclude-standard --others #{test_app_relative_path}")
        .fetch(:stdout)
        .empty?
    end

    def exit_code(command)
      shell(command).fetch(:status).success?
    end

    def shell(command)
      _stdin, stdout, stderr, process = Open3.popen3(command)

      {
        status: process.value,
        stdout: stdout.read,
        stderr: stderr.read
      }
    end
  end
end

RSpec.describe 'Snapshoot test app' do
  before(:all) do
    SnapshootSpec::TestApp.new.assert_pristine!
  end
end
