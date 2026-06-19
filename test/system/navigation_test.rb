require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  test "an admin sees the primary navigation on the dashboard" do
    # Real signed-in admin signals: the account link plus populated nav links.
    assert_selector "a[aria-label='Account']"
    assert_selector "nav[aria-label='Primary navigation'] a.nav-link"
    # The dashboard surfaces the core modules an admin can reach.
    assert_text "Tasks"
    assert_text "Log Book"
  end

  test "navigating to the account page works through Turbo" do
    find(".sidebar-account").click
    # Headless Chrome occasionally drops a click right after a navigation (the
    # same flake ApplicationSystemTestCase handles for form submits); if Turbo
    # hasn't navigated, the click was lost — click the link again.
    find(".sidebar-account").click unless has_current_path?(account_path, wait: 3)

    # assert_current_path waits for Turbo Drive to finish navigating before
    # checking content — prevents a timing failure on slow CI runners.
    assert_current_path account_path
    assert_selector "h2", text: "Change password"
  end
end
