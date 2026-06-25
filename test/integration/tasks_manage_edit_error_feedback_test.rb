require "test_helper"

# The edit-task form keeps "Sort order" (position) inside a collapsed "More
# options" disclosure. A blank position fails validation ("Sort order is not a
# number"), but before the fix the failed save re-rendered with that disclosure
# still collapsed — so the error banner named a field the manager couldn't see
# anywhere on screen, a dead end with no obvious recovery. The form must reopen
# the disclosure that holds the errored field, mirroring how the guided wizard
# reopens the step that holds its error.
class TasksManageEditErrorFeedbackTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @list = TaskList.create!(name: "Prep", position: 1, active: true)
    @task = @list.tasks.create!(
      title: "Slice tomatoes",
      recurrence_type: "daily",
      starts_on: Date.current,
      due_time: Time.zone.parse("23:59"),
      position: 2
    )
  end

  test "a blank sort order re-renders with the error named by its label" do
    patch tasks_manage_task_path(@task), params: { task: { position: "" } }

    assert_response :unprocessable_entity
    assert_includes response.body, "Sort order is not a number"
    refute_includes response.body, "Position is not a number",
      "the error must speak the form label, not the raw column name"
  end

  test "a blank sort order reopens the More options disclosure so the field is visible" do
    patch tasks_manage_task_path(@task), params: { task: { position: "" } }

    assert_response :unprocessable_entity
    more_options = more_options_disclosure(response.body)
    assert more_options, "the form should still render the More options disclosure"
    assert more_options.key?("open"),
      "the disclosure holding the errored Sort order field must be open, not collapsed out of sight"
    assert more_options.at_css("input[name='task[position]']"),
      "the reopened disclosure should contain the Sort order field the error refers to"
  end

  test "a valid save keeps the More options disclosure collapsed" do
    patch tasks_manage_task_path(@task), params: { task: { position: 5 } }
    assert_redirected_to tasks_manage_tasks_path

    # On a fresh edit load (no errors) the disclosure stays collapsed as before.
    get edit_tasks_manage_task_path(@task)
    assert_response :success
    refute more_options_disclosure(response.body).key?("open"),
      "with no error the disclosure should remain collapsed"
  end

  private

  def more_options_disclosure(html)
    Nokogiri::HTML(html).css("details").find do |details|
      details.at_css("summary")&.text&.strip == "More options"
    end
  end
end
