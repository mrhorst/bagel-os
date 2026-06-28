require "test_helper"

# The Follow-ups detail page is reached from the Follow-ups index and sends its
# mobile top-left chevron back to the list (honoring the ?scope= tab the user was
# on). But the detail page exposed no in-content desktop control back to the
# list: the only mobile-hidden back affordance was the chevron, which lives in
# the mobile-only header. On a wide screen (no mobile header) the only way back
# was the global sidebar's "Follow-ups" item, which renders as the *active* entry
# on this page — so a user had to click the already-active nav item to "go back".
# Every sibling detail page (Inventory → "Back to Inventory", Imports → "All
# imports", Order Guides → "All guides") mirrors its mobile chevron with a
# desktop-visible control; these assert the Follow-ups detail now does too,
# without disturbing the mobile chevron or its scope-preserving destination.
class FollowUpsBackNavigationTest < ActionDispatch::IntegrationTest
  # Strip the chrome hidden on desktop (the mobile screen header) and the
  # always-present global sidebar, so what's left is the in-content page body a
  # wide-screen user navigates by.
  def in_content_links_to(path)
    doc = Nokogiri::HTML(response.body)
    doc.css(".mobile-screen-header, .app-sidebar").remove
    doc.css("a").select { |a| a["href"] == path }
  end

  test "the detail page offers a desktop-visible way back to Follow-ups" do
    follow_up = FollowUp.create!(title: "Door squeaks", urgency: "normal", opened_at: 1.hour.ago, opened_by: users(:one))

    get follow_up_path(follow_up)
    assert_response :success
    assert in_content_links_to(follow_ups_path).any?,
      "expected an in-content link back to Follow-ups on the detail page"
    # The mobile chevron stays the primary mobile back affordance.
    assert_select "a.mobile-header-back[href=?]", follow_ups_path
  end

  test "the desktop back control preserves the tab the user came from" do
    # Reached from the Resolved tab (?scope=resolved), the desktop back arrow must
    # return to the Resolved list — not the default Open list — just like the
    # mobile chevron does, so the user keeps their place.
    follow_up = FollowUp.create!(title: "Old issue", urgency: "important", opened_at: 1.day.ago, opened_by: users(:one),
                                 status: "resolved", resolved_at: 1.hour.ago, resolved_by: users(:one), resolved_via: "action_taken")

    get follow_up_path(follow_up, scope: "resolved")
    assert_response :success
    assert in_content_links_to(follow_ups_path(scope: "resolved")).any?,
      "expected the desktop back link to carry ?scope=resolved"
    assert_select "a.mobile-header-back[href=?]", follow_ups_path(scope: "resolved")
  end
end
