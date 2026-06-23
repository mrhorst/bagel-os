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
end
