require "test_helper"

class TaggingTest < ActiveSupport::TestCase
  setup do
    @asset = PhotoAsset.new.tap do |asset|
      asset.photo.attach(
        io: file_fixture("photo_asset_sample.png").open,
        filename: "sample.png",
        content_type: "image/png"
      )
      asset.save!
    end
  end

  test "rejects an unknown source" do
    tagging = @asset.taggings.build(tag: tags(:food), source: "robot")
    assert_not tagging.valid?
    assert tagging.errors[:source].any?
  end

  test "is unique per photo and tag" do
    @asset.taggings.create!(tag: tags(:food), source: "manual")
    dup = @asset.taggings.build(tag: tags(:food), source: "ai")
    assert_not dup.valid?
    assert dup.errors[:tag_id].any?
  end

  test "confirmed and pending scopes split on confirmed_at" do
    confirmed = @asset.taggings.create!(tag: tags(:food), source: "manual", confirmed_at: Time.current)
    pending = @asset.taggings.create!(tag: tags(:product), source: "ai")

    assert_equal [ confirmed ], @asset.taggings.confirmed.to_a
    assert_equal [ pending ], @asset.taggings.pending.to_a
  end
end
