require "test_helper"

module Agents
  # The agent-facing output contract: errors carry actionable hints, and limited
  # reads report whether results were truncated.
  class OutputContractTest < ActiveSupport::TestCase
    include AgentCliTestHelper

    setup { authenticate_agent!(User.create!(email_address: "out@example.com", name: "Out", password: "password123", role: :admin)) }
    teardown { deauthenticate_agent! }

    test "not_found errors include a hint pointing at the next command" do
      _status, _json, err = run_cli("price:product", "no-such-thing")
      assert_equal "not_found", err.dig("error", "type")
      assert_includes err.dig("error", "hint"), "products:search"
    end

    test "ambiguous errors carry candidates and a hint" do
      list = TaskList.create!(name: "Prep", key: "prep", position: 0)
      2.times do |i|
        occ = TaskOccurrence.create!(
          task: Task.create!(task_list: list, title: "Wash bin #{i}", recurrence_type: "daily", starts_on: Date.current, due_time: "08:00", position: 0),
          task_list: list, period_kind: "day", period_starts_on: Date.current, period_ends_on: Date.current,
          due_at: Time.current.end_of_day, completion_window_ends_at: Time.current.end_of_day,
          snapshot_title: "Wash bin #{i}", snapshot_list_name: list.name, position: 0
        )
        occ
      end

      _status, _json, err = run_cli("tasks:complete", "--task", "wash bin")
      assert_equal "ambiguous", err.dig("error", "type")
      assert err.dig("error", "candidates").size >= 2
      assert err.dig("error", "hint").present?
    end

    test "the auth gate hint names the login command" do
      deauthenticate_agent!
      _status, _json, err = run_cli("tasks:lists")
      assert_equal "unauthenticated", err.dig("error", "type")
      assert_includes err.dig("error", "hint"), "login"
    end

    test "a limited read reports truncated=true when more rows exist" do
      supplier = Supplier.create!(name: "Sup")
      3.times { |i| Product.create!(canonical_name: "Bagel #{i}", supplier: supplier) }

      _status, json, = run_cli("products:search", "bagel", "--limit", "2")
      assert_equal 2, json.dig("data", "returned")
      assert_equal 2, json.dig("data", "limit")
      assert_equal true, json.dig("data", "truncated")
    end

    test "a limited read reports truncated=false when the set fits" do
      supplier = Supplier.create!(name: "Sup")
      Product.create!(canonical_name: "Lonely Bagel", supplier: supplier)

      _status, json, = run_cli("products:search", "lonely", "--limit", "25")
      assert_equal 1, json.dig("data", "returned")
      assert_equal false, json.dig("data", "truncated")
    end

    test "schema documents the hint and pagination conventions" do
      _status, json, = run_cli("schema")
      envelope = json.dig("data", "envelope")
      assert envelope["error_hint"].present?
      assert envelope["pagination"].present?
      assert_includes envelope["error_types"], "unauthenticated"
    end

    test "schema documents the production-write confirmation and environment conventions" do
      _status, json, = run_cli("schema")
      envelope = json.dig("data", "envelope")
      assert_includes envelope["error_types"], "confirmation_required"
      assert_includes envelope["error_types"], "connection_error"
      assert envelope["environment"].present?

      global = json.dig("data", "global_options").map { |o| o["name"] }
      assert_includes global, "yes"
    end

    test "every response names the environment it ran against" do
      _status, json, = run_cli("whoami")
      assert_equal "test", json["environment"]
    end
  end
end
