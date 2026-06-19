require "test_helper"

class FollowUpTest < ActiveSupport::TestCase
  def open_follow_up(**attrs)
    FollowUp.create!({ title: "Walk-in door left ajar", urgency: "important", opened_at: Time.current }.merge(attrs))
  end

  test "resolve! records who closed it, when, and how" do
    follow_up = open_follow_up
    closer = users(:one)

    follow_up.resolve!(user: closer, note: "Latched and checked the seal", via: "action_taken")

    assert follow_up.resolved?
    assert_equal closer, follow_up.resolved_by
    assert_equal "Latched and checked the seal", follow_up.resolution_note
    assert_equal "action_taken", follow_up.resolved_via
    assert_not_nil follow_up.resolved_at
  end

  test "reopen! clears the resolution but preserves the original opener" do
    opener = users(:one)
    follow_up = open_follow_up(opened_by: opener)
    follow_up.resolve!(user: users(:two))

    follow_up.reopen!(user: users(:two))

    assert follow_up.open?
    assert_nil follow_up.resolved_at
    assert_nil follow_up.resolved_via
    assert_nil follow_up.resolution_note
    assert_equal opener, follow_up.opened_by
  end

  test "open and resolved scopes partition by status" do
    still_open = open_follow_up
    closed = open_follow_up
    closed.resolve!(user: users(:one))

    assert_includes FollowUp.open, still_open
    assert_not_includes FollowUp.open, closed
    assert_includes FollowUp.resolved, closed
  end

  test "by_urgency orders urgent, then important, then normal" do
    normal = open_follow_up(urgency: "normal")
    urgent = open_follow_up(urgency: "urgent")
    important = open_follow_up(urgency: "important")

    assert_equal [urgent, important, normal], FollowUp.by_urgency.to_a
  end

  test "validates urgency, status, and resolution kind" do
    assert_not FollowUp.new(title: "x", opened_at: Time.current, urgency: "bogus").valid?
    assert_not FollowUp.new(title: "x", opened_at: Time.current, status: "archived").valid?
    assert_not FollowUp.new(title: "x", opened_at: Time.current, resolved_via: "made_up").valid?
    # resolved_via is optional (allow_blank), so a bare open follow-up is fine.
    assert open_follow_up.valid?
  end
end
