require "test_helper"

module Agents
  # Covers the voice-driven slice: the schema catalog an agent reads to map
  # transcribed intent, and the mutating commands (with fuzzy targeting,
  # ambiguity refusal, dry-run, and the photo-evidence guard).
  class VoiceActionsTest < ActiveSupport::TestCase
    include AgentCliTestHelper

    def staff
      @staff ||= User.create!(email_address: "maria@example.com", name: "Maria", password: "password123", role: :admin)
    end

    # Sign in as Maria up front: she's the user these tests attribute work to,
    # and commands now require authentication.
    setup { authenticate_agent!(staff) }
    teardown { deauthenticate_agent! }

    def task_list
      @task_list ||= TaskList.create!(name: "Cleaning", key: "cleaning-#{SecureRandom.hex(4)}", position: 0)
    end

    def task(title:)
      Task.create!(
        task_list: task_list,
        title: title,
        recurrence_type: "daily",
        starts_on: Date.current,
        due_time: "09:00",
        position: 0
      )
    end

    # A daily occurrence dated today lands in actionable_daily_scope, so fuzzy
    # --task targeting can find it.
    def occurrence(title:, requires_photo_evidence: false)
      today = Date.current
      TaskOccurrence.create!(
        task: task(title: title),
        task_list: task_list,
        period_kind: "day",
        period_starts_on: today,
        period_ends_on: today,
        due_at: Time.current.end_of_day,
        completion_window_ends_at: Time.current.end_of_day,
        snapshot_title: title,
        snapshot_list_name: task_list.name,
        requires_photo_evidence: requires_photo_evidence,
        position: 0
      )
    end

    test "schema lists every command with its mutates flag and params" do
      _status, json, = run_cli("schema")
      commands = json.dig("data", "commands")
      complete = commands.find { |c| c["command"] == "tasks:complete" }
      assert_equal true, complete["mutates"]
      assert_equal true, complete["requires_auth"]
      # --user is optional now: attribution defaults to the logged-in user.
      assert_equal false, complete["params"].find { |p| p["name"] == "user" }["required"]

      search = commands.find { |c| c["command"] == "products:search" }
      assert_equal false, search["mutates"]
      assert_equal true, search["requires_auth"]
    end

    test "tasks:complete completes by fuzzy title, attributing to the user" do
      target = occurrence(title: "Sweep front of house")

      status, json, = run_cli("tasks:complete", "--task", "sweep front", "--user", "maria@example.com")
      assert_equal 0, status
      assert_equal true, json.dig("data", "completed")
      assert_equal "completed", json.dig("data", "occurrence", "status")
      assert_equal "Maria", json.dig("data", "completion", "completed_by")
      assert target.reload.active_completion.present?
    end

    test "tasks:complete --dry-run resolves without writing" do
      target = occurrence(title: "Wipe counters")

      status, json, = run_cli("tasks:complete", "--task", "wipe", "--user", "Maria", "--dry-run")
      assert_equal 0, status
      assert_equal true, json.dig("data", "dry_run")
      assert_equal target.id, json.dig("data", "occurrence", "id")
      assert_nil target.reload.active_completion
    end

    test "an ambiguous fuzzy match is refused with candidates" do
      a = occurrence(title: "Pull cream cheese from walk-in")
      b = occurrence(title: "Restock cream cheese station")

      status, _json, err = run_cli("tasks:complete", "--task", "cream cheese", "--user", "maria@example.com")
      assert_equal 1, status
      assert_equal "ambiguous", err.dig("error", "type")
      ids = err.dig("error", "candidates").map { |c| c["id"] }
      assert_includes ids, a.id
      assert_includes ids, b.id
      assert_nil a.reload.active_completion
    end

    test "a photo-required task cannot be completed from the CLI" do
      target = occurrence(title: "Restock station", requires_photo_evidence: true)

      status, _json, err = run_cli("tasks:complete", "--occurrence", target.id.to_s, "--user", "maria@example.com")
      assert_equal 1, status
      assert_equal "usage_error", err.dig("error", "type")
      assert_match(/photo evidence/, err.dig("error", "message"))
      assert_nil target.reload.active_completion
    end

    test "completing without --user attributes to the logged-in user" do
      target = occurrence(title: "Take out trash")
      status, json, = run_cli("tasks:complete", "--occurrence", target.id.to_s)
      assert_equal 0, status
      assert_equal "Maria", json.dig("data", "completion", "completed_by")
    end

    test "an unknown user is not_found" do
      target = occurrence(title: "Lock up")
      status, _json, err = run_cli("tasks:complete", "--occurrence", target.id.to_s, "--user", "ghost@example.com")
      assert_equal 1, status
      assert_equal "not_found", err.dig("error", "type")
    end

    test "tasks:undo reverses a completion made the same day" do
      target = occurrence(title: "Sweep back of house")
      Tasks::CompleteOccurrence.new.call(occurrence: target, user: staff)

      status, json, = run_cli("tasks:undo", "--occurrence", target.id.to_s, "--user", "maria@example.com")
      assert_equal 0, status
      assert_equal true, json.dig("data", "undone")
      assert_nil target.reload.active_completion
    end

    test "undoing a task that is not completed is a usage error" do
      target = occurrence(title: "Mop floor")
      status, _json, err = run_cli("tasks:undo", "--occurrence", target.id.to_s, "--user", "maria@example.com")
      assert_equal 1, status
      assert_equal "usage_error", err.dig("error", "type")
    end

    test "staff:list returns attributable users" do
      staff
      _status, json, = run_cli("staff:list")
      emails = json.dig("data", "staff").map { |s| s["email"] }
      assert_includes emails, "maria@example.com"
    end
  end
end
