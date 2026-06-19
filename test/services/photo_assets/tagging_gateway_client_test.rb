require "test_helper"

module PhotoAssets
  class TaggingGatewayClientTest < ActiveSupport::TestCase
    test "unconfigured client reports so and returns nil from call" do
      client = TaggingGatewayClient.new(endpoint: nil, token: nil)
      assert_not client.configured?
      assert_nil client.call({}, image_base64: "x", image_mime: "image/png")
    end

    test "chat completions payload carries the model, instructions, and a data-URL image" do
      client = TaggingGatewayClient.new(endpoint: "https://gw.example/v1/chat/completions", token: "t", model: "hermes-photo-tagging")
      payload = client.send(:chat_completions_payload, { "gateway" => "photo_tagging" }, image_base64: "QUJD", image_mime: "image/jpeg")

      assert_equal "hermes-photo-tagging", payload["model"]
      parts = payload["messages"].first["content"]
      assert_includes parts.first["text"], "photo_tagging"
      assert_equal "data:image/jpeg;base64,QUJD", parts.last["image_url"]["url"]
    end

    test "chat completions responses parse plain, fenced, and prose-wrapped JSON" do
      client = TaggingGatewayClient.new(endpoint: "https://gw.example/v1/chat/completions")
      result = { "tags" => [ "food" ] }

      [
        JSON.generate(result),
        "```json\n#{JSON.generate(result)}\n```",
        "Here you go:\n#{JSON.generate(result)}"
      ].each do |content|
        response = { "choices" => [ { "message" => { "content" => content } } ] }
        assert_equal result, client.send(:parse_chat_completions_response, response), "failed for #{content.inspect}"
      end
    end
  end
end
