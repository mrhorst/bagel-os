require "test_helper"

module PhotoAssets
  class AiTreatmentTest < ActiveSupport::TestCase
    class FakeGateway
      attr_reader :last_instructions

      def initialize(result, configured: true)
        @result = result
        @configured = configured
      end

      def configured? = @configured

      def call(instructions, image_base64:, image_mime:)
        @last_instructions = instructions
        @result
      end
    end

    test "treat! attaches the edited copy from the gateway and keeps the original" do
      asset = create_asset
      asset.update!(treatment_instructions: "Remove the rag on the counter.")
      original_checksum = asset.photo.checksum
      gateway = FakeGateway.new([ "fake-image-bytes", "image/png" ])

      assert AiTreatment.new(gateway_client: gateway).treat!(asset)

      asset.reload
      assert asset.treated_photo.attached?
      assert_equal "photo-#{asset.id}-treated.png", asset.treated_photo.filename.to_s
      assert_not_nil asset.treated_at
      assert_equal original_checksum, asset.photo.checksum
      assert_equal asset.treated_photo, asset.publishable_photo
      assert_includes gateway.last_instructions, "Remove the rag on the counter."
    end

    test "treat! is false when the gateway is unconfigured or returns no image" do
      asset = create_asset

      assert_not AiTreatment.new(gateway_client: FakeGateway.new(nil, configured: false)).treat!(asset)
      assert_not AiTreatment.new(gateway_client: FakeGateway.new(nil)).treat!(asset)
      assert_not asset.reload.treated_photo.attached?
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
