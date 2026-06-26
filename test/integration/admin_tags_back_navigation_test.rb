require "test_helper"

# Marketing tags (admin/tags) is not a registered nav module, so the mobile
# screen header's auto back-chevron — which points a module page at its hub —
# never fires on these screens. The new/edit pages already override
# :mobile_left_action to point "Tags" back at the index, but the index itself
# had no override and no auto chevron, so on mobile it rendered with no header
# back affordance at all — a dead end, even though it's only reachable via the
# photo library's "Manage tags" button. These assert the index now mirrors the
# library back-chevron its sibling photo pages use, while the children still
# return to the index.
class AdminTagsBackNavigationTest < ActionDispatch::IntegrationTest
  test "the tags index has a mobile back-chevron to the photo library it's reached from" do
    get admin_tags_path
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", photo_assets_path
    # It must not strand the user with no header back affordance.
    assert_select "a.mobile-header-back", count: 1
  end

  test "the new-tag page still returns to the tags index, not the library" do
    get new_admin_tag_path
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", admin_tags_path
    assert_select "a.mobile-header-back[href=?]", photo_assets_path, count: 0
  end

  test "the edit-tag page still returns to the tags index" do
    get edit_admin_tag_path(tags(:food))
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", admin_tags_path
  end
end
