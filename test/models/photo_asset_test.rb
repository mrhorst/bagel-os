require "test_helper"

class PhotoAssetTest < ActiveSupport::TestCase
  test "defaults to pending and saves with an attached image" do
    asset = build_asset
    assert asset.save
    assert_equal "pending", asset.status
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

  test "status_label calls pending Untagged" do
    assert_equal "Untagged", build_asset.tap(&:save!).status_label
  end

  test "refresh_status! tracks the tagging lifecycle" do
    asset = build_asset.tap(&:save!)
    assert_equal "pending", asset.status

    pending = asset.taggings.create!(tag: tags(:food), source: "ai")
    assert_equal "needs_review", asset.reload.status

    pending.update!(confirmed_at: Time.current)
    assert_equal "tagged", asset.reload.status

    pending.destroy!
    assert_equal "pending", asset.reload.status
  end

  test "tagged_with finds photos by a confirmed tag slug" do
    confirmed = build_asset.tap(&:save!)
    confirmed.taggings.create!(tag: tags(:food), source: "manual", confirmed_at: Time.current)

    suggested = build_asset.tap(&:save!)
    suggested.taggings.create!(tag: tags(:food), source: "ai") # unconfirmed

    assert_equal [ confirmed.id ], PhotoAsset.tagged_with("food").ids
  end

  test "search matches caption, notes, and tag names" do
    asset = build_asset(caption: "Bagel platter").tap(&:save!)
    asset.taggings.create!(tag: tags(:food), source: "manual", confirmed_at: Time.current)

    assert_includes PhotoAsset.search("platter").ids, asset.id
    assert_includes PhotoAsset.search("food").ids, asset.id
    assert_empty PhotoAsset.search("espresso machine").ids
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
