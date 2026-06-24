require "test_helper"

# A task's edit page is reachable from three trees, and the back arrow + post-save
# redirect must return the user to the one they came from:
#
#   • Settings → Manage tasks → Edit task          → back to the management index
#   • Work surface → occurrence detail → Edit task → back to that occurrence
#   • Follow-up → "Tasks spawned" → the task        → back to that follow-up
#
# Before the fix, the cross-tree links carried no origin, the edit page's back
# arrow was hardcoded to the management index, and #update always redirected
# there — so a manager who tapped through, fixed a typo, and saved was stranded
# deep in Settings, with a back arrow that pointed at the management index
# instead of the place they came from.
#
# The occurrence link now carries origin=occurrence (+ the occurrence id) and the
# follow-up's spawned-task link carries origin=follow_up (+ the follow_up id);
# ManageController resolves the back target and the post-save redirect from it.
class TasksEditTaskOriginTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "occurrence 'Edit task' link carries origin so the edit page can return there" do
    occ = build_occurrence

    get tasks_occurrence_path(occ)
    assert_response :success

    edit_link = Nokogiri::HTML(response.body).css("a").find { |a| a.text.strip == "Edit task" }
    assert edit_link, "occurrence detail should offer an 'Edit task' link to a manager"

    params = Rack::Utils.parse_query(URI.parse(edit_link["href"]).query)
    assert_equal "occurrence", params["origin"]
    assert_equal occ.id.to_s, params["occurrence_id"]
  end

  test "editing a task from an occurrence returns to that occurrence, not Settings" do
    occ = build_occurrence
    task = occ.task

    # Edit page reached from the work surface: back arrow points at the occurrence.
    get edit_tasks_manage_task_path(task, origin: "occurrence", occurrence_id: occ.id)
    assert_response :success
    back = Nokogiri::HTML(response.body).at_css("a.subpage-back")
    assert_equal tasks_occurrence_path(occ), back["href"],
      "the edit page's back arrow must return to the originating occurrence"
    assert_equal "Back to #{occ.snapshot_title}", back["aria-label"]

    # Saving returns to that occurrence rather than dumping the user in Settings.
    patch tasks_manage_task_path(task, origin: "occurrence", occurrence_id: occ.id),
      params: { task: { title: "Slice tomatoes finely" } }
    assert_redirected_to tasks_occurrence_path(occ)
  end

  test "editing a task from Settings still returns to the management index" do
    task = build_occurrence.task

    get edit_tasks_manage_task_path(task)
    assert_response :success
    back = Nokogiri::HTML(response.body).at_css("a.subpage-back")
    assert_equal tasks_manage_tasks_path, back["href"],
      "the Settings-tree edit page keeps its back arrow to the management index"
    assert_equal "Back to Tasks", back["aria-label"]

    patch tasks_manage_task_path(task), params: { task: { title: "Slice tomatoes" } }
    assert_redirected_to tasks_manage_tasks_path
  end

  test "origin=occurrence is ignored when the occurrence does not belong to the task" do
    occ = build_occurrence
    other_task = TaskList.create!(name: "Cleaning").tasks.create!(
      title: "Wipe shelves", recurrence_type: "daily", starts_on: Date.current,
      due_time: Time.zone.parse("23:59")
    )

    # A hand-edited query string pairing an unrelated occurrence with this task
    # must fall back to the management index, not the unrelated occurrence.
    patch tasks_manage_task_path(other_task, origin: "occurrence", occurrence_id: occ.id),
      params: { task: { title: "Wipe shelves twice" } }
    assert_redirected_to tasks_manage_tasks_path
  end

  test "follow-up 'Tasks spawned' link carries origin so the edit page can return there" do
    follow_up, task = build_follow_up_with_task

    get follow_up_path(follow_up)
    assert_response :success

    link = Nokogiri::HTML(response.body).at_css("a.follow-up-task-link")
    assert link, "the follow-up should list its spawned task as a link"

    parsed = Rack::Utils.parse_query(URI.parse(link["href"]).query)
    assert_equal "follow_up", parsed["origin"]
    assert_equal follow_up.id.to_s, parsed["follow_up_id"]
  end

  test "editing a task from a follow-up returns to that follow-up, not Settings" do
    follow_up, task = build_follow_up_with_task

    # Edit page reached from the follow-up: back arrow points at the follow-up.
    get edit_tasks_manage_task_path(task, origin: "follow_up", follow_up_id: follow_up.id)
    assert_response :success
    back = Nokogiri::HTML(response.body).at_css("a.subpage-back")
    assert_equal follow_up_path(follow_up), back["href"],
      "the edit page's back arrow must return to the originating follow-up"
    assert_equal "Back to #{follow_up.title}", back["aria-label"]

    # Saving returns to that follow-up rather than dumping the user in Settings.
    patch tasks_manage_task_path(task, origin: "follow_up", follow_up_id: follow_up.id),
      params: { task: { title: "Service the walk-in now" } }
    assert_redirected_to follow_up_path(follow_up)
  end

  test "origin=follow_up is ignored when the follow-up did not spawn the task" do
    _follow_up, task = build_follow_up_with_task
    unrelated = FollowUp.create!(title: "Reorder cups", urgency: "normal",
      status: "open", opened_at: Time.current)

    # A hand-edited query string pairing an unrelated follow-up with this task
    # must fall back to the management index, not the unrelated follow-up.
    get edit_tasks_manage_task_path(task, origin: "follow_up", follow_up_id: unrelated.id)
    back = Nokogiri::HTML(response.body).at_css("a.subpage-back")
    assert_equal tasks_manage_tasks_path, back["href"]

    patch tasks_manage_task_path(task, origin: "follow_up", follow_up_id: unrelated.id),
      params: { task: { title: "Service the walk-in twice" } }
    assert_redirected_to tasks_manage_tasks_path
  end

  private

  def build_follow_up_with_task
    follow_up = FollowUp.create!(
      title: "Walk-in cooler running warm",
      urgency: "important",
      status: "open",
      opened_at: Time.current
    )
    list = TaskList.create!(name: "Follow-up tasks")
    task = list.tasks.create!(
      title: "Service the walk-in",
      recurrence_type: "daily",
      starts_on: Date.current,
      due_time: Time.zone.parse("23:59"),
      requires_photo_evidence: false
    )
    follow_up.task_links.create!(task: task, link_kind: "one_shot")
    [ follow_up, task ]
  end

  def build_occurrence
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
