require "test_helper"

class MarketingExportsTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  test "employee without the marketing module cannot export" do
    sign_in_as(users(:two))
    get photo_asset_exports_path
    assert_redirected_to root_path
  end

  test "downloads the current library filter as a zip" do
    sign_in_as(users(:one))
    create_asset

    get photo_asset_exports_path(scope: "all")
    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
  end

  test "downloads a whole collection as a zip" do
    sign_in_as(users(:one))
    asset = create_asset
    collections(:summer).collection_memberships.create!(photo_asset: asset)

    get photo_asset_exports_path(collection_id: collections(:summer).id)
    assert_response :success
    assert_equal "application/zip", response.media_type
  end

  test "downloads an explicit selection as a zip" do
    sign_in_as(users(:one))
    a, b = create_asset, create_asset

    post photo_asset_exports_path, params: { photo_asset_ids: [ a.id, b.id ] }
    assert_response :success
    assert_equal "application/zip", response.media_type
  end

  test "the library's ZIP download is driven by the share-sheet controller" do
    sign_in_as(users(:one))
    create_asset

    get photo_assets_path
    assert_response :success

    # The selection form carries the download controller pointed at the export
    # POST endpoint. It fetches with the page CSRF token rather than submitting
    # the form, so the old cross-endpoint formaction (which 422'd on the
    # per-form token) is gone.
    assert_select %(form[data-controller~="download"][data-download-url-value="#{photo_asset_exports_path}"][data-download-method-value="post"]), count: 1
    assert_select %(button[type="button"][data-action~="download#save"]), count: 1
    assert_select "button[formaction]", count: 0
  end

  test "an empty selection is rejected" do
    sign_in_as(users(:one))
    post photo_asset_exports_path, params: { photo_asset_ids: [] }
    assert_redirected_to photo_assets_path
    assert_equal "Select at least one photo to download.", flash[:alert]
  end

  test "exporting with no matching photos is rejected" do
    sign_in_as(users(:one))
    get photo_asset_exports_path(collection_id: collections(:instagram).id)
    assert_redirected_to photo_assets_path
    assert_equal "No photos to download.", flash[:alert]
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
