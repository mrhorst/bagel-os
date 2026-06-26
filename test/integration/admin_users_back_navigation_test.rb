require "test_helper"

# The mobile screen header renders an auto back-chevron to the current module's
# *hub* unless a page overrides :mobile_left_action to point one level up. Users
# (admin/users) live under the More hub, so without an override the chevron on
# the new/edit pages overshoots the Users index and dumps the manager on /more —
# contradicting the page's own "Back to users" control. The sibling admin/tags
# pages already override; these assert the Users pages do the same.
class AdminUsersBackNavigationTest < ActionDispatch::IntegrationTest
  test "the mobile back-chevron on the new-user page returns to the users list, not the hub above it" do
    get new_admin_user_path
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", admin_users_path
    assert_select "a.mobile-header-back[href=?]", more_hub_path, count: 0
  end

  test "the mobile back-chevron on the edit-user page returns to the users list, not the hub above it" do
    get edit_admin_user_path(users(:two))
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", admin_users_path
    assert_select "a.mobile-header-back[href=?]", more_hub_path, count: 0
  end
end
