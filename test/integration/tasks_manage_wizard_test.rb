require "test_helper"

# The guided "Add task" form is a 5-step wizard driven by task_wizard_controller.
# Required fields the model enforces server-side (a daily task needs a due time,
# a weekly task needs at least one weekday) aren't all HTML5-required, so a save
# can fail validation. When it does the form re-renders, and the wizard must
# reopen the step that holds the offending field — otherwise it collapses to
# step 1 and the error banner names a field sitting on a hidden panel.
class TasksManageWizardTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @list = TaskList.create!(name: "Prep", position: 1, active: true)
  end

  test "a daily task missing its due time reopens the timing step" do
    post tasks_manage_tasks_path, params: {
      task: {
        task_list_id: @list.id,
        title: "Wipe counters",
        recurrence_type: "daily",
        starts_on: Date.current.to_s,
        due_time: ""
      },
      return_to: "dashboard"
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors", /Due time/i
    # Timing fields (incl. due_time) are step index 2.
    assert_select "form.task-wizard[data-task-wizard-error-step-value='2']"
  end

  test "a weekly task with no weekday selected reopens the timing step" do
    post tasks_manage_tasks_path, params: {
      task: {
        task_list_id: @list.id,
        title: "Deep clean",
        recurrence_type: "weekly",
        starts_on: Date.current.to_s,
        due_time: "09:00",
        weekdays: [ "" ]
      },
      return_to: "dashboard"
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors", /day/i
    assert_select "form.task-wizard[data-task-wizard-error-step-value='2']"
  end

  test "a missing title reopens its own step" do
    post tasks_manage_tasks_path, params: {
      task: {
        task_list_id: @list.id,
        title: "",
        recurrence_type: "daily",
        starts_on: Date.current.to_s,
        due_time: "09:00"
      },
      return_to: "dashboard"
    }

    assert_response :unprocessable_entity
    # Title is step index 1.
    assert_select "form.task-wizard[data-task-wizard-error-step-value='1']"
  end

  test "a fresh form carries no error step" do
    get new_tasks_manage_task_path(flow: "guided")

    assert_response :success
    assert_select "form.task-wizard[data-task-wizard-error-step-value='-1']"
  end
end
