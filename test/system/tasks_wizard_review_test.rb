require "application_system_test_case"

# The guided "Add task" wizard's final step is labeled "Review" in the progress
# nav. It must actually summarize what the user entered on the earlier panels —
# previously the step only showed optional settings, so the label promised a
# review the step never delivered (#279). task_wizard_controller#renderReview
# fills the summary from the live form controls each time the step opens.
class TasksWizardReviewTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    @list = TaskList.create!(name: "Prep", position: 1, active: true)
  end

  test "the final step reviews what was entered before creating the task" do
    visit new_tasks_manage_task_path(flow: "guided", return_to: "dashboard")

    select "Prep", from: "Task list"
    click_on "Next"

    fill_in "Task name", with: "Wipe counters"
    click_on "Next"

    assert_text "Set the timing"
    fill_in "Due time", with: "11:00"
    click_on "Next" # → instructions

    fill_in "Instructions", with: "Use the blue rag."
    click_on "Next" # → review

    assert_text "Review"
    within ".task-wizard-review" do
      assert_text "Prep"
      assert_text "Wipe counters"
      assert_text "Daily"
      assert_text "due 11:00 AM"
      assert_text "Use the blue rag."
    end
  end

  test "editing an earlier step and returning refreshes the review summary" do
    visit new_tasks_manage_task_path(flow: "guided", return_to: "dashboard")

    select "Prep", from: "Task list"
    click_on "Next"
    fill_in "Task name", with: "First name"
    click_on "Next"
    fill_in "Due time", with: "09:00"
    click_on "Next" # → instructions
    click_on "Next" # → review

    within(".task-wizard-review") { assert_text "First name" }

    # Jump back to the title step, change it, and return to review.
    find("button.task-wizard-step[data-task-wizard-index-param='1']").click
    fill_in "Task name", with: "Renamed task"
    find("button.task-wizard-step[data-task-wizard-index-param='4']").click

    within ".task-wizard-review" do
      assert_text "Renamed task"
      assert_no_text "First name"
    end
  end
end
