require "test_helper"

class TasksDashboardTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "dashboard shows a card per list with today's counts" do
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
      assert_select ".tasks-kpi strong", text: "1", minimum: 1
      assert_select ".tasks-list-picker-card h2", text: "Opening"
      assert_select ".tasks-list-picker-card .badge", text: /1 late/
      assert_select ".tasks-list-picker-card .badge", text: /1 monthly/
      # The dashboard is a list picker now; tasks themselves are not rendered here.
      assert_select ".task-card-title", count: 0
    end
  end

  test "focused list view renders today and monthly tasks for that list" do
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

      get tasks_list_path(list)

      assert_response :success
      assert_select "h1", "Opening"
      assert_select ".task-card-title", text: /Check display case/
      assert_select ".badge", text: "Late"
      assert_select "h2", text: "This month"
      assert_select ".task-card-title", text: /Change AC filter/
    end
  end

  test "lists outside their display window still appear on the dashboard but are dimmed" do
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
      assert_select ".tasks-list-picker-card h2", text: "Opening"
      # Closing list is still tappable — just dimmed because its window is closed.
      assert_select ".tasks-list-picker-card-quiet h2", text: "Closing"
    end
  end

  test "completes and undoes normal task from board workflow" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      occurrence = build_today_occurrence

      post tasks_occurrence_completion_path(occurrence), params: { notes: "Done before lunch." }

      # No referer in the test → fallback to /tasks.
      assert_redirected_to tasks_root_path
      follow_redirect!
      assert_match "Completed Check display case.", response.body
      assert_equal "completed", occurrence.reload.status

      # Per-task completion details live on the focused list view now.
      get tasks_list_path(occurrence.task_list)
      assert_match "Completed by one@example.com", response.body

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
      occurrence = build_today_occurrence(requires_photo_evidence: true)

      post tasks_occurrence_completion_path(occurrence)

      assert_redirected_to tasks_root_path
      follow_redirect!
      assert_match "Photo is required for this task", response.body
      assert_nil occurrence.reload.active_completion
    end
  end

  test "one-time task hides from the dashboard the day after it was completed" do
    list = TaskList.create!(name: "Follow-up tasks", position: 1)
    task = list.tasks.create!(
      title: "Snake the toilet",
      recurrence_type: "one_time",
      one_time_on: Date.new(2026, 5, 18),
      due_time: Time.zone.parse("17:00")
    )

    # Complete it on the 19th.
    travel_to Time.zone.local(2026, 5, 19, 10) do
      Tasks::OccurrenceBuilder.new.build!(from: Date.current, to: Date.current)
      occurrence = task.task_occurrences.sole
      post tasks_occurrence_completion_path(occurrence), params: { notes: "Done." }
    end

    # The day of completion: still appears (as "Done").
    travel_to Time.zone.local(2026, 5, 19, 22) do
      get tasks_root_path
      assert_select ".tasks-list-picker-card h2", text: "Follow-up tasks"
    end

    # The next day: hidden — it shouldn't keep popping up forever.
    travel_to Time.zone.local(2026, 5, 20, 9) do
      get tasks_root_path
      assert_select ".tasks-list-picker-card h2", text: "Follow-up tasks", count: 0
    end

    # Pager back to the completion day: still there (locked to that day).
    travel_to Time.zone.local(2026, 5, 20, 9) do
      get tasks_root_path(date: "2026-05-19")
      assert_select ".tasks-list-picker-card h2", text: "Follow-up tasks"
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
