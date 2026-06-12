require "test_helper"

module PhotoAssets
  class AiTreatmentTest < ActiveSupport::TestCase
    test "attach_treated! attaches the edited copy and keeps the original" do
      asset = create_asset
      original_checksum = asset.photo.checksum

      AiTreatment.new(api_key: "test").attach_treated!(asset, "fake-image-bytes", "image/png")

      asset.reload
      assert asset.treated_photo.attached?
      assert_equal "photo-#{asset.id}-treated.png", asset.treated_photo.filename.to_s
      assert_not_nil asset.treated_at
      assert_equal original_checksum, asset.photo.checksum
      assert_equal asset.treated_photo, asset.publishable_photo
    end

    test "extract_image reads both camelCase and snake_case response shapes" do
      treatment = AiTreatment.new(api_key: "test")
      data = Base64.strict_encode64("edited")

      camel = { "candidates" => [ { "content" => { "parts" => [
        { "text" => "done" },
        { "inlineData" => { "mimeType" => "image/png", "data" => data } }
      ] } } ] }
      snake = { "candidates" => [ { "content" => { "parts" => [
        { "inline_data" => { "mime_type" => "image/jpeg", "data" => data } }
      ] } } ] }

      assert_equal [ "edited", "image/png" ], treatment.send(:extract_image, camel)
      assert_equal [ "edited", "image/jpeg" ], treatment.send(:extract_image, snake)
      assert_nil treatment.send(:extract_image, { "candidates" => [] })
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
