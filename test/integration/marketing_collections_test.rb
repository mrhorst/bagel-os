require "test_helper"

class MarketingCollectionsTest < ActionDispatch::IntegrationTest
  test "adding a photo to a collection creates a membership" do
    asset = create_asset

    assert_difference "CollectionMembership.count", 1 do
      post photo_asset_collection_memberships_path(asset), params: { collection_id: collections(:summer).id }
    end
    membership = asset.collection_memberships.sole
    assert_equal collections(:summer), membership.collection
    assert_equal users(:one), membership.added_by
  end

  test "adding the same photo to a collection twice is a no-op" do
    asset = create_asset
    collections(:summer).collection_memberships.create!(photo_asset: asset)

    assert_no_difference "CollectionMembership.count" do
      post photo_asset_collection_memberships_path(asset), params: { collection_id: collections(:summer).id }
    end
  end

  test "removing a photo from a collection deletes the membership but keeps the photo" do
    asset = create_asset
    membership = collections(:summer).collection_memberships.create!(photo_asset: asset)

    assert_difference -> { CollectionMembership.count } => -1, -> { PhotoAsset.count } => 0 do
      delete photo_asset_collection_membership_path(asset, membership)
    end
  end

  test "the collection page lists its photos" do
    asset = create_asset
    asset.update!(caption: "Hero bagel")
    collections(:summer).collection_memberships.create!(photo_asset: asset)

    get collection_path(collections(:summer))
    assert_response :success
    assert_select "a.photo-card", 1
  end

  test "the collection ZIP download opens in a new context so the standalone PWA can't trap the user" do
    asset = create_asset
    collections(:summer).collection_memberships.create!(photo_asset: asset)

    get collection_path(collections(:summer))
    assert_response :success
    # Same-window nav to the attachment strands the standalone PWA on a
    # back-button-less download view; target=_blank gives it an escapable one.
    assert_select %(a[href="#{photo_asset_exports_path(collection_id: collections(:summer).id)}"][target="_blank"]), count: 1
  end

  test "toggling favorite stars and unstars a photo" do
    asset = create_asset
    assert_not asset.favorite?

    patch toggle_favorite_photo_asset_path(asset)
    assert asset.reload.favorite?

    patch toggle_favorite_photo_asset_path(asset)
    assert_not asset.reload.favorite?
  end

  test "favorites filter shows only starred photos" do
    starred = create_asset
    starred.update_column(:favorite, true)
    create_asset # not starred

    get photo_assets_path(favorites: 1)
    assert_response :success
    assert_select "a.photo-card", 1
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
