require "test_helper"

module PhotoAssets
  class TreatmentGatewayClientTest < ActiveSupport::TestCase
    DATA_URL = "data:image/png;base64,#{Base64.strict_encode64('edited')}".freeze

    test "unconfigured client reports so and returns nil from call" do
      client = TreatmentGatewayClient.new(endpoint: nil, token: nil)
      assert_not client.configured?
      assert_nil client.call("fix it", image_base64: "x", image_mime: "image/png")
    end

    test "falls back to the review gateway env when no treatment-specific endpoint is set" do
      original = ENV["MARKETING_PHOTO_AGENT_GATEWAY_URL"]
      ENV["MARKETING_PHOTO_AGENT_GATEWAY_URL"] = "https://gw.example/v1/chat/completions"
      assert TreatmentGatewayClient.new.configured?
    ensure
      original.nil? ? ENV.delete("MARKETING_PHOTO_AGENT_GATEWAY_URL") : ENV["MARKETING_PHOTO_AGENT_GATEWAY_URL"] = original
    end

    test "chat completions payload requests image output with the photo as a data URL" do
      client = TreatmentGatewayClient.new(endpoint: "https://gw.example/v1/chat/completions", model: "hermes-photo-treatment")
      payload = client.send(:chat_completions_payload, "clean the plate", image_base64: "QUJD", image_mime: "image/jpeg")

      assert_equal "hermes-photo-treatment", payload["model"]
      assert_equal [ "image", "text" ], payload["modalities"]
      parts = payload["messages"].first["content"]
      assert_equal "clean the plate", parts.first["text"]
      assert_equal "data:image/jpeg;base64,QUJD", parts.last["image_url"]["url"]
    end

    test "parses the edited image from the common chat completions response shapes" do
      client = TreatmentGatewayClient.new(endpoint: "https://gw.example/v1/chat/completions")

      shapes = [
        { "images" => [ { "type" => "image_url", "image_url" => { "url" => DATA_URL } } ] },
        { "content" => [ { "type" => "text", "text" => "done" }, { "type" => "image_url", "image_url" => { "url" => DATA_URL } } ] },
        { "content" => "Here is the edited photo: #{DATA_URL}" }
      ]

      shapes.each do |message|
        response = { "choices" => [ { "message" => message } ] }
        assert_equal [ "edited", "image/png" ], client.send(:parse_chat_completions_response, response), "failed for #{message.keys}"
      end

      text_only = { "choices" => [ { "message" => { "content" => "I cannot edit images." } } ] }
      assert_nil client.send(:parse_chat_completions_response, text_only)
    end

    test "parses the generic gateway response shape" do
      client = TreatmentGatewayClient.new(endpoint: "https://gw.example/agents/photos")
      response = { "photo" => { "mime_type" => "image/jpeg", "data_base64" => Base64.strict_encode64("edited") } }

      assert_equal [ "edited", "image/jpeg" ], client.send(:parse_generic_response, response)
      assert_nil client.send(:parse_generic_response, { "photo" => {} })
    end
  end
end
