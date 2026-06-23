require "application_system_test_case"

# The occurrence detail page (/tasks/occurrences/:id) carries its own
# "Complete task" / "Undo completion" forms. The completions controller answers
# Turbo requests by replacing the dashboard's task ROW and KPI squares — neither
# of which exists on the detail page — so a Turbo submit there used to no-op
# silently: the completion happened server-side but the page never reflected it
# and gave no feedback. These tests drive the real browser and assert the page
# actually updates.
class TaskOccurrenceCompletionTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  test "completing a task from the occurrence detail page reflects the completion" do
    occurrence = open_occurrence_today

    visit tasks_occurrence_path(occurrence)
    assert_button "Complete task"

    click_on "Complete task"

    # The page must show the completion landed: the Current Completion panel is
    # populated and the complete form is gone. On the old code the Turbo stream
    # targeted a row absent from this page, so nothing changed here.
    assert_text "Completed by"
    assert_no_button "Complete task"
  end

  test "the back arrow keeps pointing at the originating list after completing there" do
    occurrence = open_occurrence_today

    # Arrive the way a person does: from the focused list, tap the task.
    visit tasks_list_path(occurrence.task_list)
    click_on occurrence.snapshot_title
    assert_current_path tasks_occurrence_path(occurrence)

    # Before completing, back honors where we came from (the list).
    assert_equal tasks_list_path(occurrence.task_list),
      URI(find("a.subpage-back")[:href]).path

    # Completing submits a full-page form that reloads this page with its OWN url
    # as the referer. The arrow must still (a) never point at the page it sits on
    # — that's a dead-end loop where "back" appears to do nothing — and (b) keep
    # naming the list the user was working from, instead of decaying to the
    # dashboard and dropping them out of their place in the list.
    click_on "Complete task"
    assert_text "Completed by"

    landed = URI(find("a.subpage-back")[:href]).path
    assert_not_equal tasks_occurrence_path(occurrence), landed,
      "Back arrow points at the occurrence page itself — a dead-end loop"
    assert_equal tasks_list_path(occurrence.task_list), landed,
      "Back arrow forgot the originating list and decayed to the dashboard"
    assert_includes find("a.subpage-back").text, occurrence.task_list.name
  end

  test "the back target survives an undo from the occurrence detail page too" do
    occurrence = open_occurrence_today

    visit tasks_list_path(occurrence.task_list)
    click_on occurrence.snapshot_title
    click_on "Complete task"
    assert_text "Completed by"

    check "Confirm undo"
    click_on "Undo completion"
    assert_button "Complete task"

    assert_equal tasks_list_path(occurrence.task_list),
      URI(find("a.subpage-back")[:href]).path,
      "Back arrow forgot the originating list after undoing"
  end

  test "undoing a completion from the occurrence detail page reflects the undo" do
    occurrence = open_occurrence_today
    visit tasks_occurrence_path(occurrence)
    click_on "Complete task"
    assert_text "Completed by"

    check "Confirm undo"
    click_on "Undo completion"

    # Back to an open occurrence: the complete form returns and the active
    # completion panel is gone.
    assert_button "Complete task"
    assert_no_text "Completed by"
  end

  private

  # An occurrence that is open (not missed) right now, so the detail page shows
  # the completion form rather than the missed/closed states.
  def open_occurrence_today
    list = TaskList.create!(name: "Cleaning")
    task = list.tasks.create!(
      title: "Clean slicer",
      recurrence_type: "daily",
      starts_on: Date.current,
      due_time: Time.zone.parse("23:59"),
      requires_photo_evidence: false
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
      requires_photo_evidence: false
    )
  end
end
