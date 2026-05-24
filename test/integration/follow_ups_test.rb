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
