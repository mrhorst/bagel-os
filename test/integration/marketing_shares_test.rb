require "test_helper"

class MarketingSharesTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  test "creating a share link mints one active link, reusing it on repeat" do
    sign_in_as(users(:one))
    collection = collections(:summer)

    assert_difference "Share.count", 1 do
      post collection_shares_path(collection)
    end
    assert_no_difference "Share.count" do
      post collection_shares_path(collection)
    end
    assert collection.shares.active.one?
  end

  test "revoking a share link stops it working" do
    sign_in_as(users(:one))
    share = collections(:summer).shares.create!

    delete collection_share_path(collections(:summer), share)
    assert share.reload.revoked?
  end

  test "the public gallery renders for a usable token without a login" do
    asset = create_asset
    collections(:summer).collection_memberships.create!(photo_asset: asset)
    share = collections(:summer).shares.create!

    get shared_collection_path(share.token)
    assert_response :success
    assert_select "h1", collections(:summer).name
    assert_select "a.photo-card", 1
  end

  test "a revoked token 404s with a friendly, branded unavailable page" do
    share = collections(:summer).shares.create!
    share.revoke!

    get shared_collection_path(share.token)
    assert_response :not_found
    # Not a blank 404 body: the external viewer is told the link is gone and
    # what to do next, on the public-shell layout.
    assert_select "h1", /no longer available/i
    assert_select ".empty-state"
    assert_select ".public-footer"
  end

  test "an unknown token 404s with the friendly unavailable page" do
    get shared_collection_path("nope-not-a-real-token")
    assert_response :not_found
    assert_select "h1", /no longer available/i
  end

  test "an expired token 404s with the friendly unavailable page" do
    share = collections(:summer).shares.create!(expires_at: 1.day.ago)

    get shared_collection_path(share.token)
    assert_response :not_found
    assert_select "h1", /no longer available/i
  end

  test "the public download returns a zip without a login" do
    asset = create_asset
    collections(:summer).collection_memberships.create!(photo_asset: asset)
    share = collections(:summer).shares.create!

    get shared_collection_download_path(share.token)
    assert_response :success
    assert_equal "application/zip", response.media_type
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
