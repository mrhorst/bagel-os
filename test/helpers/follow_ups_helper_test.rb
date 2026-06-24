require "test_helper"

class FollowUpsHelperTest < ActionView::TestCase
  test "urgency badge class encodes severity, mirroring the card left-rule" do
    assert_equal "badge badge-danger",  follow_up_urgency_badge_class("urgent")
    assert_equal "badge badge-warning", follow_up_urgency_badge_class("important")
    assert_equal "badge",               follow_up_urgency_badge_class("normal")
  end

  test "an unknown urgency falls back to the neutral badge" do
    assert_equal "badge", follow_up_urgency_badge_class("whatever")
  end
end
