require "test_helper"

class TasksDashboardTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
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
      TaskBriefing.create!(
        scope_type: "tasks_dashboard",
        scope_key: "today",
        generated_at: Time.current,
        stale_after: 1.hour.from_now,
        input_digest: "test",
        headline: "1 task is late",
        next_action: "Start with Check display case.",
        priority_items: [
          {
            "task_occurrence_id" => 123,
            "title" => "Check display case",
            "list_name" => "Opening",
            "status" => "late",
            "due_label" => "8:00 AM",
            "reason" => "It is already late."
          }
        ],
        source_task_occurrence_ids: [ 123 ]
      )

      get tasks_root_path

      assert_response :success
      assert_select "turbo-cable-stream-source"
      assert_select "h1", "Tasks"
      assert_select ".tasks-kpi strong", text: "1", minimum: 1
      assert_select ".tasks-list-picker-card h2", text: "Opening"
      assert_select ".tasks-list-picker-card .badge", text: /1 late/
      assert_select ".tasks-list-picker-card .badge", text: /1 monthly/
      assert_select ".tasks-briefing h2", text: /1 task is late/
      assert_select ".tasks-briefing-priority-title", text: "Check display case"
      # The dashboard is a list picker now; tasks themselves are not rendered here.
      assert_select ".task-card-title", count: 0
    end
  end

  test "dashboard reads saved briefing without generating during page load" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      list = TaskList.create!(name: "Opening", position: 1)
      list.tasks.create!(
        title: "Check display case",
        recurrence_type: "daily",
        starts_on: Date.new(2026, 5, 18),
        due_time: Time.zone.parse("08:00")
      )
      saved = TaskBriefing.create!(
        scope_type: "tasks_dashboard",
        scope_key: "today",
        generated_at: 2.hours.ago,
        stale_after: 1.hour.ago,
        input_digest: "old-digest",
        headline: "Saved recommendation",
        next_action: "Use the already saved briefing.",
        priority_items: [],
        source_task_occurrence_ids: []
      )

      assert_no_enqueued_jobs only: Tasks::GenerateBriefingJob do
        get tasks_root_path
      end

      assert_response :success
      assert_select ".tasks-briefing h2", text: "Saved recommendation"
      assert_equal "old-digest", saved.reload.input_digest
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
      assert_select "turbo-cable-stream-source"
      assert_select "h1", "Opening"
      assert_select ".task-card-title", text: /Check display case/
      assert_select ".badge", text: "Late"
      assert_select "h2", text: "This month"
      assert_select ".task-card-title", text: /Change AC filter/
    end
  end

  test "lists outside their display window are hidden from the live dashboard" do
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
      assert_select ".tasks-list-picker-card h2", text: "Closing", count: 0
      assert_select ".tasks-kpi strong", text: "1", minimum: 1
    end
  end

  test "focused list view redirects when a list is outside its display window" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      closing = TaskList.create!(
        name: "Closing",
        position: 1,
        display_start_time: Time.zone.parse("14:00"),
        display_end_time: Time.zone.parse("22:00")
      )
      closing.tasks.create!(
        title: "Clean slicer",
        recurrence_type: "daily",
        starts_on: Date.new(2026, 5, 18),
        due_time: Time.zone.parse("15:00")
      )

      get tasks_list_path(closing)

      assert_redirected_to tasks_root_path
      follow_redirect!
      assert_match "Closing is not visible on the Tasks screen right now.", response.body
      assert_select ".tasks-list-picker-card h2", text: "Closing", count: 0
    end
  end

  test "focused list view renders once the list display window opens" do
    travel_to Time.zone.local(2026, 5, 18, 14, 30) do
      closing = TaskList.create!(
        name: "Closing",
        position: 1,
        display_start_time: Time.zone.parse("14:00"),
        display_end_time: Time.zone.parse("22:00")
      )
      closing.tasks.create!(
        title: "Clean slicer",
        recurrence_type: "daily",
        starts_on: Date.new(2026, 5, 18),
        due_time: Time.zone.parse("15:00")
      )

      get tasks_list_path(closing)

      assert_response :success
      assert_select "h1", "Closing"
      assert_select ".task-card-title", text: /Clean slicer/
    end
  end

  test "completes and undoes normal task from board workflow" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      occurrence = build_today_occurrence

      assert_enqueued_with job: Tasks::GenerateBriefingJob do
        post tasks_occurrence_completion_path(occurrence), params: { notes: "Done before lunch." }
      end

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

      assert_enqueued_with job: Tasks::GenerateBriefingJob do
        delete tasks_occurrence_completion_path(occurrence), params: { confirm_undo: "1", undone_note: "Wrong tap." }
      end
      assert_redirected_to tasks_root_path
      follow_redirect!
      assert_match "Undid Check display case.", response.body
      assert_nil occurrence.reload.active_completion
      assert_equal "Wrong tap.", occurrence.task_completions.undone.sole.undone_note
    end
  end

  test "completed task circle guards undo with a confirmation on the focused list view" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      occurrence = build_today_occurrence
      post tasks_occurrence_completion_path(occurrence), params: { notes: "Done before lunch." }
      assert_equal "completed", occurrence.reload.status

      get tasks_list_path(occurrence.task_list)
      assert_response :success

      # The completed circle is itself the submit button for an undo (DELETE),
      # so a single accidental tap would wipe the logged completion. It must
      # carry a Turbo confirmation — the same guard the occurrence detail page
      # enforces with its explicit "Confirm undo" checkbox.
      assert_select "form.task-checkbox-form[data-turbo-confirm] button.task-checkbox-completed",
        count: 1,
        message: "completed task circle must confirm before undoing a completion"
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
