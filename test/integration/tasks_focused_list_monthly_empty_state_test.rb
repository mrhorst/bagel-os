require "test_helper"

# The focused list (TaskListsController#show) splits a list into a "now" panel
# (today's daily/weekly work) and a separate "This month" panel for monthly
# tasks, which can be completed any time during the month.
#
# Before the fix, the now-panel's empty/all-done messaging spoke for the WHOLE
# list — "Nothing on this list today." / "Every task on this list is complete."
# — even when the "This month" panel below was showing open monthly tasks. A
# manager opening a list whose only work today is monthly therefore read a
# headline saying there was nothing to do, directly above the tasks to do.
#
# The now-panel copy must stay scoped to daily/weekly work when open monthly
# tasks remain, and only claim list-wide emptiness/completeness when there are
# genuinely no monthly tasks left.
class TasksFocusedListMonthlyEmptyStateTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "a monthly-only list does not claim 'Nothing on this list today' above its monthly tasks" do
    list = TaskList.create!(name: "Monthly Deep Cleans")
    monthly_occurrence(list, "Deep clean fryer")

    get tasks_list_path(list)
    assert_response :success

    assert_select ".tasks-month-panel", { text: /Deep clean fryer/ },
      "the monthly task should render in the This month section"
    assert_not_includes response.body, "Nothing on this list today",
      "the now panel must not deny work that the monthly section is showing"
    assert_select ".tasks-now-panel .empty-state strong",
      text: "No daily or weekly tasks due today."
  end

  test "all daily done with an open monthly task does not claim every task is complete" do
    list = TaskList.create!(name: "Mixed")
    daily = daily_occurrence(list, "Slice tomatoes")
    Tasks::CompleteOccurrence.new.call(occurrence: daily, user: users(:one), notes: nil, photo: nil)
    monthly_occurrence(list, "Descale machine")

    get tasks_list_path(list)
    assert_response :success

    assert_select ".tasks-now-panel .empty-state strong", text: "All done for today."
    assert_not_includes response.body, "Every task on this list is complete",
      "an open monthly task means the list is not fully complete"
    assert_select ".tasks-now-panel .empty-state", text: /monthly tasks are below/
  end

  test "a genuinely empty list still reads 'Nothing on this list today'" do
    list = TaskList.create!(name: "Quiet List")

    get tasks_list_path(list)
    assert_response :success

    assert_select ".tasks-now-panel .empty-state strong", text: "Nothing on this list today."
  end

  test "all daily done and no monthly still reads 'Every task on this list is complete'" do
    list = TaskList.create!(name: "Daily Only")
    daily = daily_occurrence(list, "Wipe counters")
    Tasks::CompleteOccurrence.new.call(occurrence: daily, user: users(:one), notes: nil, photo: nil)

    get tasks_list_path(list)
    assert_response :success

    assert_select ".tasks-now-panel .empty-state", text: /Every task on this list is complete/
  end

  private

  def daily_occurrence(list, title)
    task = list.tasks.create!(
      title: title, recurrence_type: "daily",
      starts_on: Date.current, due_time: Time.zone.parse("23:59"),
      requires_photo_evidence: false
    )
    task.task_occurrences.create!(
      task_list: list, period_kind: "day",
      period_starts_on: Date.current, period_ends_on: Date.current,
      due_at: 1.hour.from_now, completion_window_ends_at: 1.week.from_now,
      snapshot_title: task.title, snapshot_list_name: list.name,
      requires_photo_evidence: false
    )
  end

  def monthly_occurrence(list, title)
    task = list.tasks.create!(
      title: title, recurrence_type: "monthly",
      starts_on: Date.current.beginning_of_month,
      requires_photo_evidence: false
    )
    task.task_occurrences.create!(
      task_list: list, period_kind: "month",
      period_starts_on: Date.current.beginning_of_month,
      period_ends_on: Date.current.end_of_month,
      due_at: nil, completion_window_ends_at: nil,
      snapshot_title: task.title, snapshot_list_name: list.name,
      requires_photo_evidence: false
    )
  end
end
