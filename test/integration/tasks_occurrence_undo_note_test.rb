require "test_helper"

# The occurrence detail page's undo form guards a logged completion behind a
# "Confirm undo" checkbox. Forgetting to tick it bounces the submit with an
# alert — and the reason the user typed into the undo-note field must survive
# that bounce, the same input preservation the create/edit forms give on a
# failed save. This is a plain request test so it stays deterministic (the
# browser-driven system test covers the same behavior end-to-end).
class TasksOccurrenceUndoNoteTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "a rejected undo keeps the note the user already typed" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      occurrence = completed_occurrence

      # Undo without ticking Confirm undo — the guard rejects it.
      delete tasks_occurrence_completion_path(occurrence),
        params: { undone_note: "Logged the wrong time", back: tasks_list_path(occurrence.task_list) }

      follow_redirect!
      assert_response :success

      # The completion is still active (the undo was rejected), so the undo form
      # re-renders — and its note field must carry the reason forward.
      field = css_select("input[name='undone_note']").first
      assert field, "The undo form did not re-render after the rejected undo"
      assert_equal "Logged the wrong time", field["value"],
        "The typed undo note was discarded when the confirm-undo guard rejected the submit"
    end
  end

  test "a normal occurrence page renders an empty undo note field" do
    travel_to Time.zone.local(2026, 5, 18, 9) do
      occurrence = completed_occurrence

      get tasks_occurrence_path(occurrence)
      assert_response :success
      # No prior rejected submit: the field must start blank, not carry a stale note.
      assert_select "input[name='undone_note']" do |inputs|
        assert_empty inputs.first["value"].to_s
      end
    end
  end

  private

  # A daily occurrence, completed and still inside its undo window so the
  # occurrence page shows the undo form.
  def completed_occurrence
    list = TaskList.create!(name: "Cleaning")
    task = list.tasks.create!(
      title: "Clean slicer",
      recurrence_type: "daily",
      starts_on: Date.current,
      due_time: Time.zone.parse("23:59"),
      requires_photo_evidence: false
    )
    occurrence = task.task_occurrences.create!(
      task_list: list,
      period_kind: "day",
      period_starts_on: Date.current,
      period_ends_on: Date.current,
      due_at: 1.hour.from_now,
      completion_window_ends_at: 1.week.from_now,
      snapshot_title: task.title,
      snapshot_list_name: list.name,
      requires_photo_evidence: false
    )
    Tasks::CompleteOccurrence.new.call(occurrence: occurrence, user: users(:one))
    occurrence.reload
  end
end
