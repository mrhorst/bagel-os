require "test_helper"

module Agents
  class OptionsTest < ActiveSupport::TestCase
    test "separates positionals from --key value flags" do
      options = Options.parse([ "house blend", "--limit", "5" ])
      assert_equal "house blend", options.positional(0)
      assert_equal "5", options.value("limit")
    end

    test "supports --key=value" do
      options = Options.parse([ "--date=2026-01-01" ])
      assert_equal "2026-01-01", options.value("date")
    end

    test "a bare --flag becomes true and does not swallow a following flag" do
      options = Options.parse([ "--missing-only", "--limit", "5" ])
      assert options.flag?("missing-only")
      assert_equal "5", options.value("limit")
    end

    test "short -h is recognised as help" do
      assert Options.parse([ "-h" ]).help?
      assert Options.parse([ "--help" ]).help?
      refute Options.parse([ "x" ]).help?
    end

    test "integer parses or falls back to the default" do
      assert_equal 5, Options.parse([ "--days", "5" ]).integer("days", 7)
      assert_equal 7, Options.parse([]).integer("days", 7)
    end

    test "a non-integer value raises a UsageError" do
      assert_raises(Command::UsageError) do
        Options.parse([ "--days", "lots" ]).integer("days", 7)
      end
    end
  end
end
