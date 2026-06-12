require "test_helper"

class MarketingPhotoAssetsTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  test "employee without the marketing module is redirected away" do
    sign_in_as(users(:two))
    get photo_assets_path
    assert_redirected_to root_path
  end

  test "employee with the marketing module can open the library" do
    employee = users(:two)
    employee.grant_module("marketing")
    sign_in_as(employee)

    get photo_assets_path
    assert_response :success
  end

  test "uploading library photos and a camera photo creates one asset each" do
    sign_in_as(users(:one))

    assert_difference "PhotoAsset.count", 3 do
      post photo_assets_path, params: {
        photo_asset: {
          photos: [ sample_upload, sample_upload ],
          camera_photo: sample_upload
        }
      }
    end

    assert_redirected_to photo_assets_path(scope: "unreviewed")
    assert_equal users(:one), PhotoAsset.last.uploaded_by
    assert_equal "unreviewed", PhotoAsset.last.status
  end

  test "submitting no photos re-renders the form with an alert" do
    sign_in_as(users(:one))

    assert_no_difference "PhotoAsset.count" do
      post photo_assets_path, params: { photo_asset: { photos: [ "" ] } }
    end
    assert_redirected_to new_photo_asset_path
  end

  test "reviewing a photo records status, reviewer, and notes" do
    sign_in_as(users(:one))
    asset = create_asset

    patch photo_asset_path(asset), params: { photo_asset: { status: "needs_work", notes: "Too dark, retake." } }

    asset.reload
    assert_equal "needs_work", asset.status
    assert_equal users(:one), asset.reviewed_by
    assert_not_nil asset.reviewed_at
    assert_equal "Too dark, retake.", asset.notes
  end

  test "deleting a photo removes it from the library" do
    sign_in_as(users(:one))
    asset = create_asset

    assert_difference "PhotoAsset.count", -1 do
      delete photo_asset_path(asset)
    end
    assert_redirected_to photo_assets_path
  end

  private

  def sample_upload
    fixture_file_upload("photo_asset_sample.png", "image/png")
  end

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
