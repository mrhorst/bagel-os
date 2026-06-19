require "test_helper"
require "zip"

module PhotoAssets
  class ZipBuilderTest < ActiveSupport::TestCase
    test "bundles each photo plus a manifest.json" do
      a = create_asset(caption: "Bagel hero")
      a.taggings.create!(tag: tags(:food), source: "manual", confirmed_at: Time.current)
      b = create_asset

      bytes = ZipBuilder.new(PhotoAsset.where(id: [ a.id, b.id ])).bytes
      entries = zip_entries(bytes)

      assert_includes entries.keys, "manifest.json"
      assert_includes entries.keys, "photo-#{a.id}.png"
      assert_includes entries.keys, "photo-#{b.id}.png"

      manifest = JSON.parse(entries["manifest.json"])
      row = manifest.find { |r| r["id"] == a.id }
      assert_equal "Bagel hero", row["caption"]
      assert_equal [ "food" ], row["tags"]
    end

    test "skips assets without an attached photo gracefully" do
      asset = create_asset
      bytes = ZipBuilder.new(PhotoAsset.where(id: asset.id)).bytes
      assert_includes zip_entries(bytes).keys, "manifest.json"
    end

    private

    def zip_entries(bytes)
      entries = {}
      Zip::File.open_buffer(StringIO.new(bytes)) do |zip|
        zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
      end
      entries
    end

    def create_asset(caption: nil)
      PhotoAsset.new(caption: caption).tap do |asset|
        asset.photo.attach(
          io: file_fixture("photo_asset_sample.png").open,
          filename: "sample.png",
          content_type: "image/png"
        )
        asset.save!
      end
    end
  end
end
