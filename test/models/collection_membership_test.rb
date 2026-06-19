require "test_helper"

class CollectionMembershipTest < ActiveSupport::TestCase
  test "a photo can only be in a collection once" do
    asset = create_asset
    collection = collections(:summer)
    collection.collection_memberships.create!(photo_asset: asset)

    dup = collection.collection_memberships.build(photo_asset: asset)
    assert_not dup.valid?
    assert dup.errors[:photo_asset_id].any?
  end

  test "the same photo can live in different collections" do
    asset = create_asset
    collections(:summer).collection_memberships.create!(photo_asset: asset)
    membership = collections(:instagram).collection_memberships.build(photo_asset: asset)

    assert membership.valid?
  end

  test "destroying a collection removes its memberships but keeps the photo" do
    asset = create_asset
    collection = Collection.create!(name: "Throwaway")
    collection.collection_memberships.create!(photo_asset: asset)

    assert_difference -> { CollectionMembership.count } => -1, -> { PhotoAsset.count } => 0 do
      collection.destroy
    end
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
