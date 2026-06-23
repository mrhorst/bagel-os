require "application_system_test_case"

# The guided "Add task" wizard (task_wizard_controller) hides every step but the
# current one. The model requires a due time for a daily task, but that field
# isn't HTML5-required, so a user can walk to the end of the wizard and submit
# without one. When the save fails the form re-renders — and the wizard must
# reopen the timing step that holds the missing field, not collapse to step 1
# where the error banner names a field the user can't see.
class TasksWizardErrorStepTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    @list = TaskList.create!(name: "Prep", position: 1, active: true)
  end

  test "submitting a daily task with no due time reopens the timing step" do
    visit new_tasks_manage_task_path(flow: "guided", return_to: "dashboard")

    # Step 1 — pick the list.
    select "Prep", from: "Task list"
    click_on "Next"

    # Step 2 — name it.
    fill_in "Task name", with: "Wipe counters"
    click_on "Next"

    # Step 3 — timing. Leave Due time blank and walk to the end.
    assert_text "Set the timing"
    click_on "Next" # → instructions
    click_on "Next" # → final options
    click_on "Create task"

    # The save fails server-side (daily needs a due time). The wizard must land
    # on the timing step with the Due time field visible, not on step 1.
    assert_text "kept this task from saving"
    assert_text "Set the timing"
    assert_selector "label", text: "Due time"
    assert_no_text "Choose the list"
  end

  test "jumping past a required field then submitting reopens that step, not a silent no-op" do
    # The step nav lets a user jump straight to the last step (e.g. to "Review")
    # without filling the required title on step 2. The title input then sits on
    # a hidden panel, so the browser's native validation blocks the submit but
    # can't render its bubble — the "Create task" click used to silently do
    # nothing, stranding the user. It must instead reopen the step that holds the
    # missing field.
    visit new_tasks_manage_task_path(flow: "guided", return_to: "dashboard")

    select "Prep", from: "Task list"
    # Jump to the last step via the step nav, skipping the title (step 2).
    find("button.task-wizard-step[data-task-wizard-index-param='4']").click
    assert_text "Final options"

    click_on "Create task"

    # Lands on the title step where the missing field lives — not a dead click.
    assert_text "Name the work"
    assert_no_text "Final options"
    assert_equal 0, Task.count
  end

  test "a fully completed wizard still creates the task" do
    # Guard the happy path: turning off native validation (so the controller can
    # surface hidden-field errors itself) must not stop a valid form submitting.
    visit new_tasks_manage_task_path(flow: "guided", return_to: "dashboard")

    select "Prep", from: "Task list"
    click_on "Next"
    fill_in "Task name", with: "Wipe counters"
    click_on "Next"
    assert_text "Set the timing"
    fill_in "Due time", with: "11:00"
    click_on "Next" # → instructions
    click_on "Next" # → final options
    click_on "Create task"

    assert_no_text "kept this task from saving"
    assert_equal 1, Task.count
    assert_equal "Wipe counters", Task.last.title
  end
end
