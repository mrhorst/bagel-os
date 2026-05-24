require "test_helper"

class FollowUpsTest < ActionDispatch::IntegrationTest
  test "open tab lists open follow-ups by urgency" do
    seed_follow_ups

    get follow_ups_path
    assert_response :success

    assert_select ".follow-ups-tab.active", text: /Open/
    assert_select ".follow-up-card h2", text: "Walk-in warm"
    assert_select ".follow-up-card h2", text: "Maintenance"
    # Resolved shouldn't show on the open tab.
    assert_select ".follow-up-card h2", text: "Old issue", count: 0
  end

  test "resolved tab lists resolved follow-ups" do
    seed_follow_ups

    get follow_ups_path(scope: "resolved")
    assert_response :success
    assert_select ".follow-up-card h2", text: "Old issue"
  end

  test "resolving updates the record" do
    follow_up = FollowUp.create!(title: "Door squeaks", urgency: "normal", opened_at: 1.hour.ago, opened_by: users(:one))

    patch resolve_follow_up_path(follow_up), params: { resolution_note: "Oiled the hinge", resolved_via: "action_taken" }
    assert_redirected_to follow_ups_path

    follow_up.reload
    assert follow_up.resolved?
    assert_equal "Oiled the hinge", follow_up.resolution_note
    assert_equal "action_taken", follow_up.resolved_via
  end

  test "posting a note appends to the thread" do
    follow_up = FollowUp.create!(title: "Walk-in warm", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one))

    assert_difference -> { follow_up.notes.count }, 1 do
      post follow_up_notes_path(follow_up), params: { follow_up_note: { body: "Called the technician." } }
    end
    assert_redirected_to follow_up_path(follow_up)

    follow_up.reload
    note = follow_up.notes.last
    assert_equal "Called the technician.", note.body
    assert_equal users(:one), note.author
  end

  test "empty note body is rejected" do
    follow_up = FollowUp.create!(title: "Door squeaks", urgency: "normal", opened_at: 1.hour.ago, opened_by: users(:one))

    assert_no_difference -> { follow_up.notes.count } do
      post follow_up_notes_path(follow_up), params: { follow_up_note: { body: "" } }
    end
  end

  test "assign sets the assignee" do
    follow_up = FollowUp.create!(title: "Walk-in warm", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one))
    patch assign_follow_up_path(follow_up), params: { assigned_to_id: users(:two).id }
    assert_redirected_to follow_up_path(follow_up)
    assert_equal users(:two), follow_up.reload.assigned_to
  end

  test "unassign clears the assignee" do
    follow_up = FollowUp.create!(title: "Walk-in warm", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one), assigned_to: users(:two))
    patch assign_follow_up_path(follow_up), params: { assigned_to_id: "" }
    assert_nil follow_up.reload.assigned_to
  end

  test "spawn one-shot task creates a Task in the system list and links it" do
    follow_up = FollowUp.create!(title: "Toilet clogged", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one))

    assert_difference -> { Task.count }, 1 do
      assert_difference -> { FollowUpTaskLink.count }, 1 do
        post spawn_task_follow_up_path(follow_up),
          params: { spawn: { title: "Snake the toilet", link_kind: "one_shot", due_time: "17:00", auto_resolve: "1" } }
      end
    end

    task = Task.last
    assert_equal "Snake the toilet", task.title
    assert_equal "one_time", task.recurrence_type
    assert_equal "Follow-up tasks", task.task_list.name
    assert follow_up.reload.resolved?
    assert_equal "converted_to_task", follow_up.resolved_via
  end

  test "spawn recurring task lives in the chosen list" do
    follow_up = FollowUp.create!(title: "Clean sink", urgency: "normal", opened_at: 1.hour.ago, opened_by: users(:one))
    list = TaskList.create!(name: "Cleaning", position: 1)

    post spawn_task_follow_up_path(follow_up),
      params: { spawn: { title: "Clean bathroom sink", link_kind: "recurring", recurrence_type: "daily", task_list_id: list.id, due_time: "17:00" } }

    task = Task.last
    assert_equal "daily", task.recurrence_type
    assert_equal list, task.task_list
    refute follow_up.reload.resolved?
  end

  test "employee without permission is redirected" do
    employee = users(:two)
    sign_in_as(employee)

    get follow_ups_path
    assert_redirected_to root_path

    employee.grant_module("follow_ups")
    get follow_ups_path
    assert_response :success
  end

  private

  def seed_follow_ups
    FollowUp.create!(title: "Walk-in warm", urgency: "urgent",   opened_at: 30.minutes.ago, opened_by: users(:one))
    FollowUp.create!(title: "Maintenance",  urgency: "normal",   opened_at: 1.hour.ago,      opened_by: users(:one))
    FollowUp.create!(title: "Old issue",    urgency: "important", opened_at: 1.day.ago,      opened_by: users(:one),
                     status: "resolved", resolved_at: 1.hour.ago, resolved_by: users(:one), resolved_via: "action_taken")
  end
end
