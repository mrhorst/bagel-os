require "test_helper"

class TasksOccurrenceBuilderTest < ActiveSupport::TestCase
  test "builds daily occurrence with snapshot and completion window" do
    list = TaskList.create!(name: "Opening", position: 1)
    task = list.tasks.create!(
      title: "Check display case",
      instructions: "Look for gaps before the rush.",
      recurrence_type: "daily",
      starts_on: Date.new(2026, 5, 18),
      due_time: Time.zone.parse("08:30"),
      position: 2
    )

    Tasks::OccurrenceBuilder.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 7))).build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))

    occurrence = task.task_occurrences.sole
    assert_equal "day", occurrence.period_kind
    assert_equal Date.new(2026, 5, 18), occurrence.period_starts_on
    assert_equal Time.zone.local(2026, 5, 18, 8, 30), occurrence.due_at
    assert_equal Time.zone.local(2026, 5, 19), occurrence.completion_window_ends_at
    assert_equal "Check display case", occurrence.snapshot_title
    assert_equal "Opening", occurrence.snapshot_list_name
    assert_equal 2, occurrence.position
  end

  test "builds weekly occurrences only for selected weekdays" do
    list = TaskList.create!(name: "Cleaning")
    task = list.tasks.create!(
      title: "Clean hood filters",
      recurrence_type: "weekly",
      starts_on: Date.new(2026, 5, 18),
      due_time: Time.zone.parse("15:00"),
      weekdays: [ 1, 3 ]
    )

    Tasks::OccurrenceBuilder.new.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 24))

    assert_equal [ Date.new(2026, 5, 18), Date.new(2026, 5, 20) ], task.task_occurrences.order(:period_starts_on).pluck(:period_starts_on)
  end

  test "builds due times in the restaurant local timezone" do
    list = TaskList.create!(name: "Midday")
    task = list.tasks.create!(
      title: "Clean slicer",
      recurrence_type: "daily",
      starts_on: Date.new(2026, 5, 18),
      due_time: Time.zone.parse("15:00")
    )

    Tasks::OccurrenceBuilder.new.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))

    occurrence = task.task_occurrences.sole
    assert_equal "Eastern Time (US & Canada)", Time.zone.name
    assert_equal Time.utc(2026, 5, 18, 19), occurrence.due_at.utc
    assert_equal "open", occurrence.status(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 14, 59)))
    assert_equal "late", occurrence.status(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 15)))
  end

  test "builds monthly occurrences as calendar month windows" do
    list = TaskList.create!(name: "Maintenance")
    task = list.tasks.create!(
      title: "Change AC filter",
      recurrence_type: "monthly",
      starts_on: Date.new(2026, 5, 1)
    )

    Tasks::OccurrenceBuilder.new.build!(from: Date.new(2026, 5, 15), to: Date.new(2026, 6, 15))

    occurrences = task.task_occurrences.order(:period_starts_on)
    assert_equal [ Date.new(2026, 5, 1), Date.new(2026, 6, 1) ], occurrences.pluck(:period_starts_on)
    assert_nil occurrences.first.due_at
    assert_equal Date.new(2026, 5, 31), occurrences.first.period_ends_on
    assert_equal Time.zone.local(2026, 6, 1), occurrences.first.completion_window_ends_at
  end

  test "one-time task rolls forward as late until completed" do
    list = TaskList.create!(name: "Repairs")
    task = list.tasks.create!(
      title: "Fix loose shelf",
      recurrence_type: "one_time",
      one_time_on: Date.new(2026, 5, 10),
      due_time: Time.zone.parse("16:00")
    )

    Tasks::OccurrenceBuilder.new.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))

    occurrence = task.task_occurrences.sole
    assert_equal Date.new(2026, 5, 10), occurrence.period_starts_on
    assert_nil occurrence.completion_window_ends_at
    assert_equal "late", occurrence.status(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 9)))
    assert occurrence.completable?(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 9)))
  end

  test "builder refreshes open snapshots but not completed history" do
    list = TaskList.create!(name: "Opening")
    user = User.create!(email_address: "demo-#{SecureRandom.hex(2)}@example.com", password: "password", name: "Demo Staff")
    task = list.tasks.create!(
      title: "Check case",
      recurrence_type: "daily",
      starts_on: Date.new(2026, 5, 18),
      due_time: Time.zone.parse("08:00")
    )
    builder = Tasks::OccurrenceBuilder.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 7)))
    builder.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))

    occurrence = task.task_occurrences.sole
    Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 7, 30))).call(occurrence: occurrence, user: user)
    task.update!(title: "Check front case")
    builder.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))

    assert_equal "Check case", occurrence.reload.snapshot_title
  end
end
