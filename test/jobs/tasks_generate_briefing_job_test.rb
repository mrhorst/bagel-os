require "test_helper"

class TasksGenerateBriefingJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "creates today's dashboard briefing" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      list = TaskList.create!(name: "Opening", position: 1)
      list.tasks.create!(
        title: "Check display case",
        recurrence_type: "daily",
        starts_on: Date.current,
        due_time: Time.zone.parse("08:00")
      )

      assert_difference "TaskBriefing.count", 1 do
        Tasks::GenerateBriefingJob.perform_now(now: Time.current)
      end

      briefing = TaskBriefing.find_by!(scope_type: "tasks_dashboard", scope_key: "today")
      assert_match "1 task is late", briefing.headline
      assert_equal "Check display case", briefing.priority_items.first["title"]
    end
  end
end
