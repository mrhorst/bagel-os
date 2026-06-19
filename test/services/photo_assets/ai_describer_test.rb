require "test_helper"

module PhotoAssets
  class AiDescriberTest < ActiveSupport::TestCase
    # Minimal stand-in for the gateway so the write path is testable offline.
    class StubGateway
      def initialize(response)
        @response = response
      end

      def configured? = true
      def call(*) = @response
    end

    test "apply! stores caption, hashtags, and alt text and stamps the pass" do
      asset = create_asset

      AiDescriber.new.apply!(asset, caption: "Golden bagels, fresh out.", hashtags: "#bagel #brunch", alt_text: "A tray of bagels")

      asset.reload
      assert_equal "Golden bagels, fresh out.", asset.suggested_caption
      assert_equal "#bagel #brunch", asset.hashtags
      assert_equal "A tray of bagels", asset.alt_text
      assert_not_nil asset.described_at
    end

    test "apply! never overwrites human-entered alt text" do
      asset = create_asset(alt_text: "Human wrote this")

      AiDescriber.new.apply!(asset, caption: "x", hashtags: "", alt_text: "AI alt")

      assert_equal "Human wrote this", asset.reload.alt_text
    end

    test "apply! does not touch the human caption" do
      asset = create_asset(caption: "Human caption")

      AiDescriber.new.apply!(asset, caption: "AI caption", hashtags: "", alt_text: "")

      assert_equal "Human caption", asset.reload.caption
      assert_equal "AI caption", asset.suggested_caption
    end

    test "normalize accepts a hashtag array and adds missing # signs" do
      result = AiDescriber.new.send(:normalize, { "caption" => "Hi", "hashtags" => [ "bagel", "#brunch" ], "alt_text" => "alt" })
      assert_equal "#bagel #brunch", result[:hashtags]
    end

    test "normalize accepts a hashtag string" do
      result = AiDescriber.new.send(:normalize, { "caption" => "Hi", "hashtags" => "bagel brunch", "alt_text" => "" })
      assert_equal "#bagel #brunch", result[:hashtags]
    end

    test "normalize returns nil when nothing usable comes back" do
      assert_nil AiDescriber.new.send(:normalize, { "caption" => "", "hashtags" => "", "alt_text" => "" })
      assert_nil AiDescriber.new.send(:normalize, "not a hash")
    end

    test "describe! fetches from the gateway and applies the copy" do
      asset = create_asset(real: true)
      gateway = StubGateway.new({ "caption" => "Crispy.", "hashtags" => "bagel", "alt_text" => "A bagel" })

      result = AiDescriber.new(gateway_client: gateway).describe!(asset)

      assert_equal asset, result
      assert_equal "Crispy.", asset.reload.suggested_caption
      assert_equal "#bagel", asset.hashtags
    end

    test "configured? reflects the gateway" do
      assert_not AiDescriber.configured? # no gateway env in test
    end

    private

    def create_asset(caption: nil, alt_text: nil, real: false)
      file = real ? "photo_asset_real.png" : "photo_asset_sample.png"
      PhotoAsset.new(caption: caption, alt_text: alt_text).tap do |asset|
        asset.photo.attach(
          io: file_fixture(file).open,
          filename: file,
          content_type: "image/png"
        )
        asset.save!
      end
    end
  end
end
