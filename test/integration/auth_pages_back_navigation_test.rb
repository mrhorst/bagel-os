require "test_helper"

# The mobile screen header renders an auto back-chevron to the current module's
# parent hub. The logged-out sign-in (sessions#new) and reset-password
# (passwords#new/#edit) pages belong to the account module, so without an
# auth gate they rendered a "Back to More" chevron — a back affordance on a
# top-level entry point that, when tapped, bounces through /more straight back
# to sign-in (every hub requires auth). These pages must show no in-app
# back-chevron; an authenticated module sub-page must still show one.
class AuthPagesBackNavigationTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  test "the sign-in page shows no mobile back-chevron when logged out" do
    get new_session_path
    assert_response :success
    assert_select "a.mobile-header-back", count: 0
    assert_select "a.mobile-header-back[href=?]", more_hub_path, count: 0
  end

  test "the reset-password request page shows no mobile back-chevron when logged out" do
    get new_password_path
    assert_response :success
    assert_select "a.mobile-header-back", count: 0
  end

  test "an authenticated module sub-page still shows its mobile back-chevron" do
    sign_in_as(users(:one))
    get new_admin_user_path
    assert_response :success
    assert_select "a.mobile-header-back"
  end
end
