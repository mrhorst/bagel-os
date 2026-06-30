require "application_system_test_case"

# Task History (/tasks/history) is a filter-first surface: you narrow by date
# range / status / list, then tap "Details" to inspect one occurrence. The
# occurrence detail page's back arrow is resolved server-side
# (Tasks::OccurrencesController#resolve_back_target) and used to drop the query
# string — so "back" returned you to the UNFILTERED default History, throwing
# away the filter you drilled in from. This test drives the real browser and
# asserts the back arrow returns to the same filtered view, mirroring the
# place-preservation Follow-ups (its tab) and the Photos library (its filter)
# already practice.
class TaskHistoryBackContextTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  test "the occurrence back arrow returns to the filtered History view it was opened from" do
    occurrence = open_occurrence_today

    # Arrive the way a person does: filter History down to one list, then tap
    # the occurrence's Details.
    visit tasks_history_path(task_list_id: occurrence.task_list_id, status: "open")
    click_on "Details"
    # The Details link carries the filtered History URL as ?back=, so the
    # occurrence path now has a query — match on the path, ignore the query.
    assert_current_path tasks_occurrence_path(occurrence), ignore_query: true

    back = URI(find("a.subpage-back")[:href])
    assert_equal tasks_history_path, back.path,
      "Back arrow no longer points at History"
    assert_includes back.query.to_s, "task_list_id=#{occurrence.task_list_id}",
      "Back arrow dropped the History filter context — it returns to the unfiltered default"
    assert_includes find("a.subpage-back").text, "History"
  end

  private

  # An occurrence that is open (not missed) right now, so it shows on the
  # default History range and the detail page renders normally.
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
