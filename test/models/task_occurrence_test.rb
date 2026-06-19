require "test_helper"

class TaskOccurrenceTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  NOW = Time.zone.local(2026, 6, 15, 12)

  setup do
    @list = TaskList.create!(name: "Prep")
    @task = @list.tasks.create!(
      title: "Prep mise en place",
      recurrence_type: "daily",
      starts_on: Date.new(2026, 6, 1),
      due_time: Time.zone.parse("10:00")
    )
  end

  def build_occurrence(starts_on:, due_at:, window:, **attrs)
    @task.task_occurrences.create!(
      task_list: @list,
      period_kind: "day",
      period_starts_on: starts_on,
      period_ends_on: starts_on,
      due_at: due_at,
      completion_window_ends_at: window,
      snapshot_title: @task.title,
      snapshot_list_name: @list.name,
      **attrs
    )
  end

  test "open while due time and completion window are still ahead" do
    travel_to NOW do
      occurrence = build_occurrence(starts_on: NOW.to_date, due_at: NOW + 2.hours, window: NOW + 1.day)

      assert_equal "open", occurrence.status
      assert occurrence.open?
      assert occurrence.completable?
    end
  end

  test "late once the due time has passed but the window is open" do
    travel_to NOW do
      occurrence = build_occurrence(starts_on: NOW.to_date, due_at: NOW - 2.hours, window: NOW + 1.day)

      assert_equal "late", occurrence.status
      assert occurrence.completable?
      assert occurrence.refreshable?
    end
  end

  test "missed once the completion window has closed" do
    travel_to NOW do
      occurrence = build_occurrence(starts_on: (NOW - 2.days).to_date, due_at: NOW - 2.days, window: NOW - 1.day)

      assert_equal "missed", occurrence.status
      assert_not occurrence.completable?
      assert_not occurrence.refreshable?
    end
  end

  test "completed (and undoable the same day) when an active completion exists" do
    travel_to NOW do
      occurrence = build_occurrence(starts_on: NOW.to_date, due_at: NOW - 2.hours, window: NOW + 1.day)
      occurrence.task_completions.create!(user: users(:one), snapshot_staff_name: "Sam", completed_at: NOW)

      assert_equal "completed", occurrence.reload.status
      assert occurrence.completed?
      assert occurrence.undoable?
    end
  end

  test "one-time occurrences with no window carry over" do
    occurrence = build_occurrence(starts_on: Date.new(2026, 6, 1), due_at: nil, window: nil)

    assert occurrence.one_time_carryover?
  end

  test "chronological and period-range scopes" do
    early = build_occurrence(starts_on: Date.new(2026, 6, 1), due_at: nil, window: nil)
    later = build_occurrence(starts_on: Date.new(2026, 6, 10), due_at: nil, window: nil)

    assert_equal [early, later], TaskOccurrence.chronological.to_a
    assert_includes TaskOccurrence.for_period_range(Date.new(2026, 6, 1), Date.new(2026, 6, 5)), early
    assert_not_includes TaskOccurrence.for_period_range(Date.new(2026, 6, 8), Date.new(2026, 6, 9)), early
  end

  test "a task may not have two occurrences for the same period" do
    build_occurrence(starts_on: Date.new(2026, 6, 3), due_at: nil, window: nil)
    duplicate = @task.task_occurrences.build(
      task_list: @list, period_kind: "day",
      period_starts_on: Date.new(2026, 6, 3), period_ends_on: Date.new(2026, 6, 3),
      snapshot_title: "x", snapshot_list_name: "y"
    )

    assert_not duplicate.valid?
  end

  test "period_ends_on must be on or after period_starts_on" do
    bad = @task.task_occurrences.build(
      task_list: @list, period_kind: "day",
      period_starts_on: Date.new(2026, 6, 5), period_ends_on: Date.new(2026, 6, 1),
      snapshot_title: "x", snapshot_list_name: "y"
    )

    assert_not bad.valid?
    assert_includes bad.errors[:period_ends_on], "must be on or after the period start"
  end
end
