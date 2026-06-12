require "test_helper"

module PhotoAssets
  class AiReviewerTest < ActiveSupport::TestCase
    test "apply! records an AI verdict with treatment instructions" do
      asset = create_asset

      AiReviewer.new(client: Object.new).apply!(asset, {
        "status" => "approved",
        "notes" => "Great light, clean the counter edge.",
        "treatment_recommended" => true,
        "treatment_instructions" => "Remove the rag on the counter."
      })

      asset.reload
      assert_equal "approved", asset.status
      assert_equal "Great light, clean the counter edge.", asset.notes
      assert_equal "ai", asset.reviewed_via
      assert asset.ai_reviewed?
      assert_nil asset.reviewed_by
      assert_not_nil asset.reviewed_at
      assert_equal "Remove the rag on the counter.", asset.treatment_instructions
    end

    test "apply! ignores treatment instructions when treatment is not recommended" do
      asset = create_asset

      AiReviewer.new(client: Object.new).apply!(asset, {
        "status" => "rejected",
        "notes" => "Out of focus.",
        "treatment_recommended" => false,
        "treatment_instructions" => "n/a"
      })

      assert_nil asset.reload.treatment_instructions
    end

    test "apply! rejects an unknown status" do
      asset = create_asset

      assert_raises(ArgumentError) do
        AiReviewer.new(client: Object.new).apply!(asset, { "status" => "maybe" })
      end
      assert_equal "unreviewed", asset.reload.status
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
