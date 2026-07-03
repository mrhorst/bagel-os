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

  # A photo opened from a collection must return to that collection, not
  # overshoot to the library. The collection show page threads from_collection
  # into each card link; the photo detail page resolves it to a real collection
  # and points both its back affordances there.
  test "a collection's photo cards carry the collection origin" do
    collection = collections(:summer)
    asset = create_asset
    collection.collection_memberships.create!(photo_asset: asset)

    get collection_path(collection)
    assert_response :success
    assert_select "a.photo-card[href=?]", photo_asset_path(asset, from_collection: collection.id)
  end

  test "the photo detail page opened from a collection returns to that collection" do
    collection = collections(:summer)
    asset = create_asset

    get photo_asset_path(asset, from_collection: collection.id)
    assert_response :success
    # Mobile chevron and desktop button both point at the collection, relabeled.
    assert_select "a.mobile-header-back[href=?]", collection_path(collection)
    assert_select "a.mobile-header-back[aria-label=?]", "Back to collection"
    assert_select "a.button[href=?]", collection_path(collection)
    # And not the library it would have overshot to before.
    assert_select "a.mobile-header-back[href=?]", photo_assets_path, count: 0
  end

  test "the photo detail page without an origin still returns to the library" do
    asset = create_asset

    get photo_asset_path(asset)
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", photo_assets_path
    assert_select "a.mobile-header-back[aria-label=?]", "Back to library"
  end

  test "a stale or forged collection origin falls back to the library" do
    asset = create_asset

    get photo_asset_path(asset, from_collection: 999_999)
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", photo_assets_path
    assert_select "a.mobile-header-back[aria-label=?]", "Back to library"
  end

  private

  def create_asset
    PhotoAsset.new.tap do |asset|
      asset.photo.attach(
        io: file_fixture("photo_asset_sample.png").open,
        filename: "sample.png",
        content_type: "image/png"
      )
      asset.save!
    end
  end
end
