require "test_helper"

class TasksSetupHistoryTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  # "Add task" reaches the same setup screen from two places: the dashboard FAB
  # and the Manage tasks list. The screen must return the user to whichever one
  # they came from — mirroring the origin pattern already used for task lists
  # (Tasks::TaskListsController#resolve_edit_back_target) — instead of always
  # dumping them on the dashboard.
  test "add task from the manage list returns the user to the manage list" do
    TaskList.create!(name: "Opening", position: 1)

    get tasks_manage_tasks_path
    assert_response :success
    # The Manage-list "Add task" button tags its origin so setup can come back here.
    assert_select "a.button.primary[href=?]", setup_tasks_manage_tasks_path(origin: "manage")

    get setup_tasks_manage_tasks_path(origin: "manage")
    assert_response :success
    # Back arrow lands on the Manage tasks list it came from, not the dashboard.
    assert_select "a.subpage-back[href=?]", tasks_manage_tasks_path
    assert_select "a.subpage-back[href=?]", tasks_root_path, count: 0
    # "Add to an existing list" threads the manage return target through creation.
    assert_select ".task-builder-menu a[href=?]",
      new_tasks_manage_task_path(flow: "guided", return_to: "manage")
  end

  test "add task from the dashboard FAB still returns to the dashboard" do
    TaskList.create!(name: "Opening", position: 1)

    get setup_tasks_manage_tasks_path
    assert_response :success
    assert_select "a.subpage-back[href=?]", tasks_root_path
    assert_select ".task-builder-menu a[href=?]",
      new_tasks_manage_task_path(flow: "guided", return_to: "dashboard")
  end

  test "new task back arrow preserves the manage origin" do
    task_list = TaskList.create!(name: "Opening", position: 1)

    get new_tasks_manage_task_path(task_list_id: task_list.id, flow: "guided", return_to: "manage")
    assert_response :success
    assert_select "a.subpage-back[href=?]", setup_tasks_manage_tasks_path(origin: "manage")
  end

  # The guided form's Cancel must honor the same origin its Back arrow and its
  # post-create redirect already honor — otherwise cancelling out of the form
  # reached from Manage strands the user on the dashboard instead of returning
  # them to the Manage tasks list they came from.
  test "new task cancel returns to the manage list when reached from manage" do
    task_list = TaskList.create!(name: "Opening", position: 1)

    get new_tasks_manage_task_path(task_list_id: task_list.id, flow: "guided", return_to: "manage")
    assert_response :success
    assert_select ".task-wizard-actions a[href=?]", tasks_manage_tasks_path
    assert_select ".task-wizard-actions a[href=?]", tasks_root_path, count: 0
  end

  test "new task cancel returns to the dashboard when reached from the dashboard" do
    task_list = TaskList.create!(name: "Opening", position: 1)

    get new_tasks_manage_task_path(task_list_id: task_list.id, flow: "guided", return_to: "dashboard")
    assert_response :success
    assert_select ".task-wizard-actions a[href=?]", tasks_root_path
  end

  test "guided task creation from the manage list returns to the manage list" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      task_list = TaskList.create!(name: "Opening", position: 1)

      post tasks_manage_tasks_path, params: {
        return_to: "manage",
        task: {
          task_list_id: task_list.id,
          title: "Check display case",
          recurrence_type: "daily",
          starts_on: "2026-05-18",
          due_time: "08:00",
          weekdays: [ "" ],
          requires_photo_evidence: "0"
        }
      }

      assert_redirected_to tasks_manage_tasks_path
      assert_equal "Check display case", Task.sole.title
    end
  end

  test "dashboard add button opens guided task setup menu" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      TaskList.create!(name: "Opening", position: 1)

      get tasks_root_path

      assert_response :success
      assert_select "a.mobile-fab[href=?]", setup_tasks_manage_tasks_path

      get setup_tasks_manage_tasks_path

      assert_response :success
      assert_select "h1", "Add task"
      assert_select ".task-builder-card strong", "Add to an existing list"
      assert_select ".task-builder-card strong", "Create a new list"
    end
  end

  test "new list from guided setup continues into guided task form" do
    post tasks_manage_lists_path, params: {
      continue_to_task: "1",
      task_list: {
        name: "Prep",
        position: 1
      }
    }

    task_list = TaskList.sole
    assert_redirected_to new_tasks_manage_task_path(task_list_id: task_list.id, flow: "guided", return_to: "dashboard")

    follow_redirect!

    assert_response :success
    assert_select ".task-wizard"
    assert_select "select[name='task[task_list_id]'] option[selected]", "Prep"
    assert_select ".task-wizard-step", 5
    assert_select "input[type='hidden'][name='task[starts_on]']", 1
    assert_select "label", text: "Start date", count: 0
    assert_select "label", text: "End date", count: 0
  end

  # The "Create a new list" builder card continues into the guided task form just
  # like "Add to an existing list" — and must thread the same origin so a manager
  # who began in Settings → Manage tasks lands back there, not on the dashboard.
  test "create-a-new-list card threads the manage origin into list creation" do
    TaskList.create!(name: "Opening", position: 1)

    get setup_tasks_manage_tasks_path(origin: "manage")
    assert_response :success
    assert_select ".task-builder-menu a[href=?]",
      new_tasks_manage_list_path(continue_to_task: "1", origin: "manage")
  end

  test "create-a-new-list card from the dashboard carries no origin" do
    TaskList.create!(name: "Opening", position: 1)

    get setup_tasks_manage_tasks_path
    assert_response :success
    assert_select ".task-builder-menu a[href=?]",
      new_tasks_manage_list_path(continue_to_task: "1")
  end

  test "new list page preserves the manage origin on its back arrow and cancel" do
    get new_tasks_manage_list_path(continue_to_task: "1", origin: "manage")

    assert_response :success
    assert_select "a.subpage-back[href=?]", setup_tasks_manage_tasks_path(origin: "manage")
    assert_select ".form-footer a[href=?]", setup_tasks_manage_tasks_path(origin: "manage")
    assert_select "input[type='hidden'][name='origin'][value=?]", "manage"
  end

  test "new list from the manage builder continues into the guided form returning to manage" do
    post tasks_manage_lists_path, params: {
      continue_to_task: "1",
      origin: "manage",
      task_list: { name: "Prep", position: 1 }
    }

    task_list = TaskList.sole
    assert_redirected_to new_tasks_manage_task_path(task_list_id: task_list.id, flow: "guided", return_to: "manage")

    follow_redirect!

    assert_response :success
    # Cancel + post-create redirect stay on the Manage tasks tree, not the dashboard.
    assert_select ".task-wizard-actions a[href=?]", tasks_manage_tasks_path
    assert_select ".task-wizard-actions a[href=?]", tasks_root_path, count: 0
  end

  test "guided task creation returns to the dashboard" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      task_list = TaskList.create!(name: "Opening", position: 1)

      post tasks_manage_tasks_path, params: {
        return_to: "dashboard",
        task: {
          task_list_id: task_list.id,
          title: "Check display case",
          instructions: "Make it full before the rush.",
          recurrence_type: "daily",
          starts_on: "2026-05-18",
          due_time: "08:00",
          weekdays: [ "" ],
          requires_photo_evidence: "0"
        }
      }

      assert_redirected_to tasks_root_path
      assert_equal "Check display case", Task.sole.title
    end
  end

  test "creates task lists and tasks from setup screens" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      get tasks_manage_lists_path
      assert_response :success
      assert_select "h1", "Task lists"

      post tasks_manage_lists_path, params: {
        task_list: {
          name: "Opening",
          position: 1,
          display_start_time: "05:00",
          display_end_time: "11:00",
          notes: "Before doors open"
        }
      }
      assert_redirected_to tasks_manage_lists_path
      task_list = TaskList.sole
      assert_equal "Opening", task_list.name
      assert_equal "05:00", task_list.display_start_time.strftime("%H:%M")
      assert_equal "11:00", task_list.display_end_time.strftime("%H:%M")

      post tasks_manage_tasks_path, params: {
        task: {
          task_list_id: task_list.id,
          title: "Check display case",
          instructions: "Make it full before the rush.",
          recurrence_type: "daily",
          starts_on: "2026-05-18",
          due_time: "08:00",
          weekdays: [ "" ],
          requires_photo_evidence: "1"
        }
      }
      assert_redirected_to tasks_manage_tasks_path

      task = Task.sole
      assert_equal "Check display case", task.title
      assert task.requires_photo_evidence?

      get tasks_manage_tasks_path
      assert_response :success
      assert_select "h1", "Tasks"
      assert_select ".badge", "Photo required"
      assert_select "h3", "Check display case"
    end
  end

  test "archives and reactivates lists and tasks without deleting completed history" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      staff = User.create!(email_address: "maria-#{SecureRandom.hex(2)}@example.com", password: "password", name: "Maria")
      task_list = TaskList.create!(name: "Opening", position: 1)
      task = task_list.tasks.create!(
        title: "Check display case",
        recurrence_type: "daily",
        starts_on: Date.new(2026, 5, 18),
        due_time: Time.zone.parse("08:00")
      )
      Tasks::OccurrenceBuilder.new.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))
      occurrence = task.task_occurrences.sole
      Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 9))).call(occurrence: occurrence, user: staff)

      patch archive_tasks_manage_list_path(task_list)

      assert_redirected_to tasks_manage_lists_path
      assert task_list.reload.archived?
      assert task.reload.archived?
      assert TaskOccurrence.exists?(occurrence.id)

      patch reactivate_tasks_manage_list_path(task_list)
      assert_redirected_to tasks_manage_lists_path
      assert task_list.reload.active?
      assert task.reload.archived?

      patch reactivate_tasks_manage_task_path(task)
      assert_redirected_to tasks_manage_tasks_path
      assert task.reload.active?
    end
  end

  test "shows filtered history, occurrence details, and undo history" do
    travel_to Time.zone.local(2026, 5, 18, 13) do
      staff = User.create!(email_address: "maria-#{SecureRandom.hex(2)}@example.com", password: "password", name: "Maria")
      task_list = TaskList.create!(name: "Closing", position: 1)
      task = task_list.tasks.create!(
        title: "Clean slicer",
        recurrence_type: "daily",
        starts_on: Date.new(2026, 5, 18),
        due_time: Time.zone.parse("12:00")
      )
      Tasks::OccurrenceBuilder.new.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))
      occurrence = task.task_occurrences.sole

      first_completion = Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 12, 20))).call(
        occurrence: occurrence,
        user: staff,
        notes: "Done after lunch."
      )
      Tasks::UndoCompletion.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 12, 30))).call(
        completion: first_completion,
        user: staff,
        note: "Wrong task."
      )
      Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 12, 40))).call(
        occurrence: occurrence,
        user: staff
      )

      get tasks_history_path, params: {
        from: "2026-05-18",
        to: "2026-05-18",
        status: "completed",
        task_list_id: task_list.id
      }

      assert_response :success
      assert_select "h1", "Task History"
      assert_select "td", text: /Clean slicer/
      assert_select "td", text: /Completed by Maria/

      get tasks_occurrence_path(occurrence)
      assert_response :success
      assert_select "h1", "Clean slicer"
      assert_select "h2", "Current Completion"
      assert_select "h2", "Undo History"
      assert_match "Wrong task.", response.body
      assert_match "Done after lunch.", response.body
    end
  end
end
