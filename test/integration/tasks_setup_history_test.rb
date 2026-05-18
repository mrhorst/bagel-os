require "test_helper"

class TasksSetupHistoryTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "creates staff members, task lists, and tasks from setup screens" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      get tasks_staff_index_path
      assert_response :success
      assert_select "h1", "Task Staff"

      post tasks_staff_index_path, params: {
        staff_member: {
          display_name: "Maria",
          notes: "Morning lead"
        }
      }
      assert_redirected_to tasks_staff_index_path
      assert_equal "Maria", StaffMember.sole.display_name

      get tasks_lists_path
      assert_response :success
      assert_select "h1", "Task Lists"

      post tasks_lists_path, params: {
        task_list: {
          name: "Opening",
          position: 1,
          display_start_time: "05:00",
          display_end_time: "11:00",
          notes: "Before doors open"
        }
      }
      assert_redirected_to tasks_lists_path
      task_list = TaskList.sole
      assert_equal "Opening", task_list.name
      assert_equal "05:00", task_list.display_start_time.strftime("%H:%M")
      assert_equal "11:00", task_list.display_end_time.strftime("%H:%M")

      post tasks_manage_path, params: {
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
      assert_redirected_to tasks_manage_path

      task = Task.sole
      assert_equal "Check display case", task.title
      assert task.requires_photo_evidence?

      get tasks_manage_path
      assert_response :success
      assert_select "h1", "Manage Tasks"
      assert_select ".badge", "Photo required"
      assert_select "h3", "Check display case"
    end
  end

  test "archives and reactivates lists and tasks without deleting completed history" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      staff = StaffMember.create!(display_name: "Maria")
      task_list = TaskList.create!(name: "Opening", position: 1)
      task = task_list.tasks.create!(
        title: "Check display case",
        recurrence_type: "daily",
        starts_on: Date.new(2026, 5, 18),
        due_time: Time.zone.parse("08:00")
      )
      Tasks::OccurrenceBuilder.new.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))
      occurrence = task.task_occurrences.sole
      Tasks::CompleteOccurrence.new(now: Time.zone.local(2026, 5, 18, 9)).call(occurrence: occurrence, staff_member: staff)

      patch archive_tasks_list_path(task_list)

      assert_redirected_to tasks_lists_path
      assert task_list.reload.archived?
      assert task.reload.archived?
      assert TaskOccurrence.exists?(occurrence.id)

      patch reactivate_tasks_list_path(task_list)
      assert_redirected_to tasks_lists_path
      assert task_list.reload.active?
      assert task.reload.archived?

      patch tasks_reactivate_managed_task_path(task)
      assert_redirected_to tasks_manage_path
      assert task.reload.active?
    end
  end

  test "shows filtered history, occurrence details, and undo history" do
    travel_to Time.zone.local(2026, 5, 18, 13) do
      staff = StaffMember.create!(display_name: "Maria")
      task_list = TaskList.create!(name: "Closing", position: 1)
      task = task_list.tasks.create!(
        title: "Clean slicer",
        recurrence_type: "daily",
        starts_on: Date.new(2026, 5, 18),
        due_time: Time.zone.parse("12:00")
      )
      Tasks::OccurrenceBuilder.new.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))
      occurrence = task.task_occurrences.sole

      first_completion = Tasks::CompleteOccurrence.new(now: Time.zone.local(2026, 5, 18, 12, 20)).call(
        occurrence: occurrence,
        staff_member: staff,
        notes: "Done after lunch."
      )
      Tasks::UndoCompletion.new(now: Time.zone.local(2026, 5, 18, 12, 30)).call(
        completion: first_completion,
        staff_member: staff,
        note: "Wrong task."
      )
      Tasks::CompleteOccurrence.new(now: Time.zone.local(2026, 5, 18, 12, 40)).call(
        occurrence: occurrence,
        staff_member: staff
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
