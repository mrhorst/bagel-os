require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  test "derives a slug from the name when blank" do
    collection = Collection.create!(name: "Fall Specials")
    assert_equal "fall-specials", collection.slug
  end

  test "keeps an explicit slug" do
    collection = Collection.create!(name: "Holiday", slug: "xmas")
    assert_equal "xmas", collection.slug
  end

  test "requires a name" do
    collection = Collection.new(name: "")
    assert_not collection.valid?
    assert collection.errors[:name].any?
  end

  test "rejects a duplicate slug" do
    dup = Collection.new(name: "Summer again", slug: "summer-menu")
    assert_not dup.valid?
    assert dup.errors[:slug].any?
  end

  test "ordered scope sorts by position then name" do
    assert_equal [ collections(:summer), collections(:instagram) ], Collection.ordered.to_a
  end

  test "cover_asset returns the most recently added photo" do
    collection = collections(:summer)
    older = create_asset
    newer = create_asset
    collection.photo_assets << older
    collection.photo_assets << newer

    assert_equal newer, collection.cover_asset
  end

  test "cover_asset is nil for an empty collection" do
    assert_nil collections(:instagram).cover_asset
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
