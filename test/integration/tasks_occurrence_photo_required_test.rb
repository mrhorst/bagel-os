require "test_helper"

# The occurrence detail page's "Complete task" form submits as a full page
# navigation (data: turbo: false). When a task requires photo evidence, the
# model rejects a completion that has no photo — but the controller answers
# that failure with a redirect, which throws away any note the user typed.
#
# Marking the photo input `required` makes the browser block the doomed submit
# up front, so the note is never lost. These guard that the attribute renders
# exactly when the task requires a photo.
class TasksOccurrencePhotoRequiredTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the photo field is required on a photo-required occurrence" do
    occurrence = open_occurrence_today(requires_photo: true)

    get tasks_occurrence_path(occurrence)
    assert_response :success

    photo_input = Nokogiri::HTML(response.body).at_css("input[type='file'][name='photo']")
    assert photo_input, "expected a photo file input on the completion form"
    assert photo_input.key?("required"),
      "the photo input must be `required` so the browser blocks a submit that " \
      "would be rejected and discard the user's note"
  end

  test "the completion form has no photo field when the task needs no photo" do
    occurrence = open_occurrence_today(requires_photo: false)

    get tasks_occurrence_path(occurrence)
    assert_response :success

    assert_nil Nokogiri::HTML(response.body).at_css("input[type='file'][name='photo']"),
      "a task without photo evidence should not render a photo input at all"
  end

  private

  def open_occurrence_today(requires_photo:)
    list = TaskList.create!(name: "Cleaning")
    task = list.tasks.create!(
      title: "Mop walk-in",
      recurrence_type: "daily",
      starts_on: Date.current,
      due_time: Time.zone.parse("23:59"),
      requires_photo_evidence: requires_photo
    )
    task.task_occurrences.create!(
      task_list: list,
      period_kind: "day",
      period_starts_on: Date.current,
      period_ends_on: Date.current,
      due_at: 1.hour.from_now,
      completion_window_ends_at: 1.week.from_now,
      snapshot_title: task.title,
      snapshot_list_name: list.name,
      requires_photo_evidence: requires_photo
    )
  end
end
