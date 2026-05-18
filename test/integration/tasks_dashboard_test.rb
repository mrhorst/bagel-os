require "test_helper"

class TasksDashboardTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "shows today's tasks and this month section" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      list = TaskList.create!(name: "Opening", position: 1)
      list.tasks.create!(
        title: "Check display case",
        recurrence_type: "daily",
        starts_on: Date.new(2026, 5, 18),
        due_time: Time.zone.parse("08:00")
      )
      list.tasks.create!(
        title: "Change AC filter",
        recurrence_type: "monthly",
        starts_on: Date.new(2026, 5, 1)
      )

      get tasks_root_path

      assert_response :success
      assert_select "h1", "Tasks"
      assert_select ".block-stat-card strong", text: "1", minimum: 2
      assert_select ".task-card-title", text: /Check display case/
      assert_select ".badge", text: "Late"
      assert_select "h2", text: "This month"
      assert_select ".task-card-title", text: /Change AC filter/
    end
  end

  test "hides task lists outside their display window" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      opening = TaskList.create!(name: "Opening", position: 1)
      closing = TaskList.create!(
        name: "Closing",
        position: 2,
        display_start_time: Time.zone.parse("12:00"),
        display_end_time: Time.zone.parse("14:30")
      )
      opening.tasks.create!(
        title: "Check display case",
        recurrence_type: "daily",
        starts_on: Date.new(2026, 5, 18),
        due_time: Time.zone.parse("08:00")
      )
      closing.tasks.create!(
        title: "Clean slicer",
        recurrence_type: "daily",
        starts_on: Date.new(2026, 5, 18),
        due_time: Time.zone.parse("13:00")
      )

      get tasks_root_path

      assert_response :success
      assert_select ".task-list-cluster h3", text: "Opening"
      assert_select ".task-list-cluster h3", text: "Closing", count: 0
      assert_select ".task-card-title", text: /Check display case/
      assert_select ".task-card-title", text: /Clean slicer/, count: 0
      assert_select ".later-tasks-panel", text: /1 task hidden/
    end

    travel_to Time.zone.local(2026, 5, 18, 12) do
      get tasks_root_path

      assert_response :success
      assert_select ".task-list-cluster h3", text: "Closing"
      assert_select ".task-card-title", text: /Clean slicer/
    end
  end

  test "requires completing as before completion" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      occurrence = build_today_occurrence

      post tasks_occurrence_completion_path(occurrence), params: { notes: "Done" }

      assert_redirected_to tasks_root_path
      follow_redirect!
      assert_match "Select who is completing tasks first.", response.body
      assert_nil occurrence.reload.active_completion
    end
  end

  test "completes and undoes normal task from board workflow" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      staff = StaffMember.create!(display_name: "Demo Staff")
      occurrence = build_today_occurrence

      patch tasks_completing_as_path, params: { staff_member_id: staff.id }
      post tasks_occurrence_completion_path(occurrence), params: { notes: "Done before lunch." }

      assert_redirected_to tasks_root_path
      follow_redirect!
      assert_match "Completed Check display case.", response.body
      assert_equal "completed", occurrence.reload.status
      assert_match "Completed by Demo Staff", response.body

      delete tasks_occurrence_completion_path(occurrence), params: { undone_note: "Wrong tap." }
      follow_redirect!
      assert_match "Confirm undo before updating task history.", response.body

      delete tasks_occurrence_completion_path(occurrence), params: { confirm_undo: "1", undone_note: "Wrong tap." }
      assert_redirected_to tasks_root_path
      follow_redirect!
      assert_match "Undid Check display case.", response.body
      assert_nil occurrence.reload.active_completion
      assert_equal "Wrong tap.", occurrence.task_completions.undone.sole.undone_note
    end
  end

  test "photo-required task rejects completion without photo" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      staff = StaffMember.create!(display_name: "Demo Staff")
      occurrence = build_today_occurrence(requires_photo_evidence: true)

      patch tasks_completing_as_path, params: { staff_member_id: staff.id }
      post tasks_occurrence_completion_path(occurrence)

      assert_redirected_to tasks_root_path
      follow_redirect!
      assert_match "Photo is required for this task", response.body
      assert_nil occurrence.reload.active_completion
    end
  end

  private

  def build_today_occurrence(requires_photo_evidence: false)
    list = TaskList.create!(name: "Opening", position: 1)
    task = list.tasks.create!(
      title: "Check display case",
      recurrence_type: "daily",
      starts_on: Date.new(2026, 5, 18),
      due_time: Time.zone.parse("10:00"),
      requires_photo_evidence: requires_photo_evidence
    )
    Tasks::OccurrenceBuilder.new.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))
    task.task_occurrences.sole
  end
end
