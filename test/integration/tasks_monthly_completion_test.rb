require "test_helper"

# Completing a MONTHLY task from a focused list's "This month" section.
#
# The focused list (TaskListsController#month_occurrences_for) excludes
# completed monthly occurrences, and the task_row partial only renders a
# completion state for daily rows (`!monthly`). Before the fix, the
# completions controller replaced a just-completed monthly row with that same
# partial, which fell through to the OPEN "Mark complete" submit branch — so a
# done task showed a "Completed" badge next to a still-tappable "Mark complete"
# circle, and tapping it again raised "Task occurrence is already completed."
#
# The Turbo-stream response must instead REMOVE the monthly row (matching the
# list's own filter and the live-update morph), while daily rows keep being
# replaced in place with a real completed circle.
class TasksMonthlyCompletionTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "completing a monthly task removes its row instead of leaving a 'Mark complete' circle" do
    occurrence = monthly_occurrence

    post tasks_occurrence_completion_path(occurrence),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success

    dom_id = ActionView::RecordIdentifier.dom_id(occurrence)
    doc = Nokogiri::HTML(response.body)

    remove_stream = doc.at_css("turbo-stream[action='remove'][target='#{dom_id}']")
    assert remove_stream,
      "expected the completed monthly row to be removed from the focused list"

    # And it must NOT be replaced with a row carrying an open 'Mark complete'
    # control — the contradiction this fixes.
    row_replace = doc.at_css("turbo-stream[action='replace'][target='#{dom_id}']")
    assert_nil row_replace,
      "a completed monthly row must not be replaced with a (contradictory) task row"
    assert_not_includes response.body, "Mark complete",
      "a completed monthly task must not render a 'Mark complete' circle"

    # The "Done" KPI still refreshes so the user gets confirmation.
    assert doc.at_css("turbo-stream[action='replace'][target='task_list_kpis_#{occurrence.task_list_id}']"),
      "the KPI squares should still refresh on completion"

    # Steady state: the list no longer shows the completed monthly row.
    get tasks_list_path(occurrence.task_list)
    assert_response :success
    assert_nil Nokogiri::HTML(response.body).at_css("##{dom_id}"),
      "the completed monthly occurrence should not appear in the focused list"
  end

  test "the monthly completion circle is guarded by a confirmation, the daily one is not" do
    monthly = monthly_occurrence
    daily = daily_occurrence_for(monthly.task_list)

    get tasks_list_path(monthly.task_list)
    assert_response :success
    doc = Nokogiri::HTML(response.body)

    monthly_row = doc.at_css("##{ActionView::RecordIdentifier.dom_id(monthly)}")
    monthly_form = monthly_row.at_css("form.task-checkbox-form")
    assert_equal "Mark Descale dish sink done for this month?",
      monthly_form["data-turbo-confirm"],
      "the monthly completion circle must confirm before silently removing the row"

    daily_row = doc.at_css("##{ActionView::RecordIdentifier.dom_id(daily)}")
    daily_form = daily_row.at_css("form.task-checkbox-form")
    assert_nil daily_form["data-turbo-confirm"],
      "the daily completion circle stays a single tap (its row is undoable in place)"
  end

  test "completing a daily task still replaces its row in place with a completed circle" do
    occurrence = daily_occurrence

    post tasks_occurrence_completion_path(occurrence),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success

    dom_id = ActionView::RecordIdentifier.dom_id(occurrence)
    doc = Nokogiri::HTML(response.body)

    replace = doc.at_css("turbo-stream[action='replace'][target='#{dom_id}'] template")
    assert replace, "expected the completed daily row to be replaced in place"
    frag = Nokogiri::HTML.fragment(replace.inner_html)
    assert frag.at_css(".task-checkbox-completed"),
      "the replaced daily row must show a completed circle"
    assert_nil frag.at_css("button.task-checkbox-open"),
      "the replaced daily row must not show an open 'Mark complete' circle"
  end

  private

  def monthly_occurrence
    list = TaskList.create!(name: "Cleaning")
    task = list.tasks.create!(
      title: "Descale dish sink",
      recurrence_type: "monthly",
      starts_on: Date.current.beginning_of_month,
      requires_photo_evidence: false
    )
    task.task_occurrences.create!(
      task_list: list,
      period_kind: "month",
      period_starts_on: Date.current.beginning_of_month,
      period_ends_on: Date.current.end_of_month,
      due_at: nil,
      completion_window_ends_at: nil,
      snapshot_title: task.title,
      snapshot_list_name: list.name,
      requires_photo_evidence: false
    )
  end

  def daily_occurrence_for(list)
    task = list.tasks.create!(
      title: "Wipe counters",
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

  def daily_occurrence
    list = TaskList.create!(name: "Prep")
    task = list.tasks.create!(
      title: "Slice tomatoes",
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
