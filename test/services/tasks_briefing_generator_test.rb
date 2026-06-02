require "test_helper"

class TasksBriefingGeneratorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "generates a saved briefing with late tasks first" do
    travel_to Time.zone.local(2026, 5, 18, 9, 0) do
      list = TaskList.create!(name: "Opening", position: 1)
      late_task = list.tasks.create!(
        title: "Check sanitizer buckets",
        instructions: "Use test strips before prep starts.",
        recurrence_type: "daily",
        starts_on: Date.current,
        due_time: Time.zone.parse("08:00"),
        position: 1
      )
      soon_task = list.tasks.create!(
        title: "Restock cream cheese",
        recurrence_type: "daily",
        starts_on: Date.current,
        due_time: Time.zone.parse("09:30"),
        position: 2
      )
      monthly_task = list.tasks.create!(
        title: "Clean ceiling vents",
        recurrence_type: "monthly",
        starts_on: Date.current.beginning_of_month,
        position: 3
      )

      operating_day = Tasks::OperatingDay.new
      Tasks::OccurrenceBuilder.new(operating_day: operating_day).build!(from: Date.current, to: Date.current)
      Tasks::OccurrenceBuilder.new(operating_day: operating_day).build!(from: Date.current.beginning_of_month, to: Date.current.end_of_month)

      briefing = Tasks::BriefingGenerator.new(operating_day: operating_day).find_or_generate!

      assert briefing.persisted?
      assert_match "1 task is late", briefing.headline
      assert_match "Start with Check sanitizer buckets", briefing.next_action
      assert_equal [
        occurrence_for(late_task, Date.current).id,
        occurrence_for(soon_task, Date.current).id,
        occurrence_for(monthly_task, Date.current.beginning_of_month).id
      ], briefing.priority_items.map { |item| item["task_occurrence_id"] }
      assert_includes briefing.source_task_occurrence_ids, occurrence_for(late_task, Date.current).id
    end
  end

  test "reuses the saved briefing when the task snapshot is unchanged" do
    travel_to Time.zone.local(2026, 5, 18, 9, 0) do
      list = TaskList.create!(name: "Opening", position: 1)
      list.tasks.create!(
        title: "Check display case",
        recurrence_type: "daily",
        starts_on: Date.current,
        due_time: Time.zone.parse("10:00")
      )

      operating_day = Tasks::OperatingDay.new
      Tasks::OccurrenceBuilder.new(operating_day: operating_day).build!(from: Date.current, to: Date.current)

      first = Tasks::BriefingGenerator.new(operating_day: operating_day).find_or_generate!
      updated_at = first.updated_at

      travel 10.minutes

      second = Tasks::BriefingGenerator.new(operating_day: Tasks::OperatingDay.new).find_or_generate!

      assert_equal first.id, second.id
      assert_equal updated_at, second.updated_at
    end
  end

  test "refreshes the saved briefing when a task moves into the due soon window" do
    travel_to Time.zone.local(2026, 5, 18, 9, 0) do
      list = TaskList.create!(name: "Opening", position: 1)
      list.tasks.create!(
        title: "Check display case",
        recurrence_type: "daily",
        starts_on: Date.current,
        due_time: Time.zone.parse("11:00")
      )

      operating_day = Tasks::OperatingDay.new
      Tasks::OccurrenceBuilder.new(operating_day: operating_day).build!(from: Date.current, to: Date.current)

      first = Tasks::BriefingGenerator.new(operating_day: operating_day).find_or_generate!
      refute_match "coming up soon", first.headline

      travel 31.minutes

      second = Tasks::BriefingGenerator.new(operating_day: Tasks::OperatingDay.new).find_or_generate!

      assert_equal first.id, second.id
      assert_operator second.updated_at, :>, first.updated_at
      assert_match "coming up soon", second.headline
    end
  end

  test "returns a quiet briefing when no task work is open" do
    travel_to Time.zone.local(2026, 5, 18, 9, 0) do
      briefing = Tasks::BriefingGenerator.new(operating_day: Tasks::OperatingDay.new).find_or_generate!

      assert_equal "No open task work needs attention right now.", briefing.headline
      assert_empty briefing.priority_items
      assert_empty briefing.source_task_occurrence_ids
    end
  end

  private

  def occurrence_for(task, starts_on)
    task.task_occurrences.find_by!(period_starts_on: starts_on)
  end
end
