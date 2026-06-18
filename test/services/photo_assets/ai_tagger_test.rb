require "test_helper"

module PhotoAssets
  class AiTaggerTest < ActiveSupport::TestCase
    test "apply! adds unconfirmed ai taggings for matching slugs and stamps the pass" do
      asset = create_asset

      applied = AiTagger.new.apply!(asset, %w[food])

      assert_equal %w[food], applied
      tagging = asset.taggings.sole
      assert_equal "ai", tagging.source
      assert_not tagging.confirmed?
      assert_not_nil asset.reload.ai_tagged_at
      assert_equal "needs_review", asset.status
    end

    test "apply! ignores slugs outside the active vocabulary" do
      asset = create_asset

      applied = AiTagger.new.apply!(asset, %w[food promo made-up])

      # promo is inactive, made-up doesn't exist — only food applies.
      assert_equal %w[food], applied
      assert_equal [ tags(:food).id ], asset.taggings.map(&:tag_id)
    end

    test "apply! with no matches still records the tagging pass and leaves the photo untagged" do
      asset = create_asset

      applied = AiTagger.new.apply!(asset, [])

      assert_empty applied
      assert_not_nil asset.reload.ai_tagged_at
      assert_equal "pending", asset.status
    end

    test "apply! does not duplicate an existing tagging" do
      asset = create_asset
      asset.taggings.create!(tag: tags(:food), source: "manual", confirmed_at: Time.current)

      AiTagger.new.apply!(asset, %w[food])

      assert_equal 1, asset.taggings.count
      assert_equal "manual", asset.taggings.sole.source
    end

    test "normalize_slugs keeps only active vocabulary slugs" do
      tagger = AiTagger.new
      vocabulary = Tag.active.to_a
      result = tagger.send(:normalize_slugs, { "tags" => [ "Food", "promo", "x" ] }, vocabulary)

      assert_equal %w[food], result
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
end
