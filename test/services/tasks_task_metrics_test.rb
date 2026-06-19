require "test_helper"

class TasksTaskMetricsTest < ActiveSupport::TestCase
  NOW = Time.zone.local(2026, 6, 15, 12)

  setup do
    @list = TaskList.create!(name: "Prep")
    @task = @list.tasks.create!(
      title: "Prep", recurrence_type: "daily",
      starts_on: Date.new(2026, 6, 1), due_time: Time.zone.parse("10:00")
    )
    @operating_day = Tasks::OperatingDay.new(now: NOW)
    @seq = 0
  end

  # Build a persisted occurrence whose status resolves to `as` under NOW.
  def occurrence(as:, kind: "day")
    @seq += 1
    day = Date.new(2026, 6, 1) + @seq.days
    due, window =
      case as
      when "open"      then [ NOW + 2.hours, NOW + 1.day ]
      when "late"      then [ NOW - 2.hours, NOW + 1.day ]
      when "missed"    then [ NOW - 2.days,  NOW - 1.day ]
      when "completed" then [ NOW - 2.hours, NOW + 1.day ]
      end

    occ = @task.task_occurrences.create!(
      task_list: @list, period_kind: kind,
      period_starts_on: day, period_ends_on: day,
      due_at: due, completion_window_ends_at: window,
      snapshot_title: @task.title, snapshot_list_name: @list.name
    )
    occ.task_completions.create!(user: users(:one), snapshot_staff_name: "Sam", completed_at: NOW) if as == "completed"
    occ
  end

  test "summary tallies each status across the daily slice and counts monthly" do
    daily = [ occurrence(as: "open"), occurrence(as: "late"), occurrence(as: "completed"), occurrence(as: "missed") ]
    monthly = [ occurrence(as: "open", kind: "month"), occurrence(as: "open", kind: "month") ]

    summary = Tasks::TaskMetrics.new(daily: daily, monthly: monthly, operating_day: @operating_day).summary

    assert_equal 1, summary.late
    assert_equal 1, summary.open
    assert_equal 1, summary.completed
    assert_equal 1, summary.missed
    assert_equal 2, summary.monthly_open
  end

  test "summary exposes today-suffixed and plain hashes" do
    summary = Tasks::TaskMetrics.new(daily: [ occurrence(as: "open") ], monthly: [], operating_day: @operating_day).summary

    assert_equal(
      { late_today: 0, open_today: 1, completed_today: 0, missed_today: 0, open_this_month: 0 },
      summary.to_h_with_today_suffix
    )
    assert_equal(
      { late: 0, open: 1, completed: 0, missed: 0, monthly_open: 0 },
      summary.to_h_no_suffix
    )
  end
end
