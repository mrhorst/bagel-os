require "test_helper"

module PhotoAssets
  class AiReviewerTest < ActiveSupport::TestCase
    class FakeGateway
      attr_reader :last_call

      def initialize(response, configured: true)
        @response = response
        @configured = configured
      end

      def configured? = @configured

      def call(payload, image_base64:, image_mime:)
        @last_call = { payload: payload, image_base64: image_base64, image_mime: image_mime }
        @response
      end
    end

    test "review! applies a verdict from the gateway" do
      asset = create_asset
      gateway = FakeGateway.new({
        "status" => "Needs work",
        "notes" => "Too dark — reshoot near the window.",
        "treatment_recommended" => "true",
        "treatment_instructions" => "Remove the rag on the counter."
      })

      verdict = AiReviewer.new(gateway_client: gateway).review!(asset)

      assert_equal "needs_work", verdict["status"]
      asset.reload
      assert_equal "needs_work", asset.status
      assert_equal "ai", asset.reviewed_via
      assert_equal "Remove the rag on the counter.", asset.treatment_instructions
      assert_equal "photo_review", gateway.last_call[:payload]["gateway"]
      assert_equal "image/png", gateway.last_call[:image_mime]
      assert gateway.last_call[:image_base64].present?
    end

    test "review! leaves the photo unreviewed when the gateway is unconfigured or returns junk" do
      asset = create_asset

      assert_nil AiReviewer.new(gateway_client: FakeGateway.new(nil, configured: false)).review!(asset)
      assert_nil AiReviewer.new(gateway_client: FakeGateway.new(nil)).review!(asset)
      assert_nil AiReviewer.new(gateway_client: FakeGateway.new({ "status" => "maybe" })).review!(asset)
      assert_equal "unreviewed", asset.reload.status
    end

    test "apply! records an AI verdict with treatment instructions" do
      asset = create_asset

      AiReviewer.new.apply!(asset, {
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

      AiReviewer.new.apply!(asset, {
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
        AiReviewer.new.apply!(asset, { "status" => "maybe" })
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
