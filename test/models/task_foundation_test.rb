require "test_helper"

class TaskFoundationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "task list archives active tasks and preserves historical occurrences" do
    list = TaskList.create!(name: "Patio", position: 1)
    task = list.tasks.create!(
      title: "Wipe patio tables",
      recurrence_type: "daily",
      starts_on: Date.new(2026, 5, 18),
      due_time: Time.zone.parse("10:00")
    )
    open_occurrence = task.task_occurrences.create!(
      task_list: list,
      period_kind: "day",
      period_starts_on: Date.new(2026, 5, 18),
      period_ends_on: Date.new(2026, 5, 18),
      due_at: Time.zone.local(2026, 5, 18, 10),
      completion_window_ends_at: Time.zone.local(2026, 5, 19),
      snapshot_title: task.title,
      snapshot_list_name: list.name
    )
    missed_occurrence = task.task_occurrences.create!(
      task_list: list,
      period_kind: "day",
      period_starts_on: Date.new(2026, 5, 17),
      period_ends_on: Date.new(2026, 5, 17),
      due_at: Time.zone.local(2026, 5, 17, 10),
      completion_window_ends_at: Time.zone.local(2026, 5, 18),
      snapshot_title: task.title,
      snapshot_list_name: list.name
    )

    travel_time = Time.zone.local(2026, 5, 18, 12)
    travel_to travel_time do
      list.archive!
    end

    assert_not list.reload.active?
    assert_not task.reload.active?
    assert_not TaskOccurrence.exists?(open_occurrence.id)
    assert TaskOccurrence.exists?(missed_occurrence.id)
  end

  test "schedule validation keeps recurrence shapes explicit" do
    list = TaskList.create!(name: "Opening")

    weekly = list.tasks.build(title: "Check bathrooms", recurrence_type: "weekly", starts_on: Date.new(2026, 5, 18), due_time: Time.zone.parse("12:00"))
    assert_not weekly.valid?
    assert_includes weekly.errors[:weekdays], "must include at least one day"

    monthly = list.tasks.build(title: "Change AC filter", recurrence_type: "monthly", starts_on: Date.new(2026, 5, 1))
    assert monthly.valid?
  end

  test "task list display window controls board visibility" do
    list = TaskList.create!(
      name: "Closing",
      display_start_time: Time.zone.parse("12:00"),
      display_end_time: Time.zone.parse("14:30")
    )

    assert_not list.visible_at?(Time.zone.local(2026, 5, 18, 9))
    assert list.visible_at?(Time.zone.local(2026, 5, 18, 12))
    assert list.visible_at?(Time.zone.local(2026, 5, 18, 14, 30))
    assert_not list.visible_at?(Time.zone.local(2026, 5, 18, 15))
  end

  test "task list display window can cross midnight" do
    list = TaskList.create!(
      name: "Overnight",
      display_start_time: Time.zone.parse("22:00"),
      display_end_time: Time.zone.parse("02:00")
    )

    assert list.visible_at?(Time.zone.local(2026, 5, 18, 23))
    assert list.visible_at?(Time.zone.local(2026, 5, 19, 1))
    assert_not list.visible_at?(Time.zone.local(2026, 5, 18, 12))
  end
end
