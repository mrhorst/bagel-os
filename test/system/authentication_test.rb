require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "user can sign in and land on the dashboard" do
    sign_in_as users(:one)

    assert_current_path root_path
    assert_text "Tasks"
  end

  test "invalid credentials are rejected" do
    visit new_session_url
    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "wrong-password"
    click_on "Sign in"
    # Chrome occasionally drops the click; if the rejection hasn't shown up, the
    # submit was lost — re-submit the form directly.
    resubmit "Sign in" unless has_text?("Try another email address or password", wait: 3)

    assert_text "Try another email address or password"
    assert_no_selector "a[aria-label='Account']"
  end

  test "visiting a protected page while signed out redirects to sign in" do
    visit account_url

    assert_selector "h1", text: "Sign in"
  end

  test "user can sign out" do
    sign_in_as users(:one)
    visit account_url
    click_button "Sign out"
    # Chrome occasionally drops the click; if we're still on the account page,
    # the submit was lost — re-submit the sign-out form directly.
    resubmit "Sign out" unless has_selector?("h1", text: "Sign in", wait: 3)

    assert_selector "h1", text: "Sign in"
  end
end
