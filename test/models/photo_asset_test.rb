require "test_helper"

class PhotoAssetTest < ActiveSupport::TestCase
  test "defaults to unreviewed and saves with an attached image" do
    asset = build_asset
    assert asset.save
    assert_equal "unreviewed", asset.status
  end

  test "requires a photo" do
    asset = PhotoAsset.new
    assert_not asset.valid?
    assert_includes asset.errors[:photo], "must be attached"
  end

  test "rejects non-image attachments" do
    asset = PhotoAsset.new
    asset.photo.attach(
      io: file_fixture("vendor_receipt_sample.csv").open,
      filename: "receipt.csv",
      content_type: "text/csv"
    )
    assert_not asset.valid?
    assert_includes asset.errors[:photo], "must be an image"
  end

  test "rejects unknown statuses" do
    asset = build_asset(status: "maybe")
    assert_not asset.valid?
    assert asset.errors[:status].any?
  end

  test "with_status scopes the library" do
    approved = build_asset(status: "approved").tap(&:save!)
    build_asset(status: "needs_work").save!

    assert_equal [ approved.id ], PhotoAsset.with_status("approved").ids
  end

  private

  def build_asset(attrs = {})
    PhotoAsset.new(attrs).tap do |asset|
      asset.photo.attach(
        io: file_fixture("photo_asset_sample.png").open,
        filename: "sample.png",
        content_type: "image/png"
      )
    end
  end
end
