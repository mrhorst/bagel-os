require "test_helper"

# Collections (marketing/collections) live under the Marketing photo library but
# are not registered as a nav module, so the mobile screen header renders no
# auto back-chevron on any collections page — leaving the app's primary (mobile)
# navigation affordance, the top-left back arrow, empty while every sibling photo
# page has one. Each page already exposes an in-content back control ("Back to
# library" / "All collections" / the form's "Cancel"); these assert the mobile
# header chevron now mirrors that same destination, one level up.
class CollectionsBackNavigationTest < ActionDispatch::IntegrationTest
  test "the collections index chevron returns to the photo library" do
    get collections_path
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", photo_assets_path
    # Must not bounce to the More hub (the would-be auto target if registered raw).
    assert_select "a.mobile-header-back[href=?]", more_hub_path, count: 0
  end

  test "a collection page chevron returns to the collections index" do
    get collection_path(collections(:summer))
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", collections_path
  end

  test "the new-collection page chevron returns to the collections index" do
    get new_collection_path
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", collections_path
  end

  test "the edit-collection page chevron returns to that collection" do
    collection = collections(:summer)
    get edit_collection_path(collection)
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", collection_path(collection)
  end
end
