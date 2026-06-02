require "test_helper"

class TasksBriefingGatewayClientTest < ActiveSupport::TestCase
  test "signs webhook requests with hmac sha256" do
    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = JSON.generate("headline" => "Ready", "next_action" => "Start here", "priority_items" => [])
    captured_request = nil

    http_start = lambda do |*, &block|
      block.call(FakeHttp.new(response) { |request| captured_request = request })
    end

    with_net_http_start(http_start) do
      client = Tasks::BriefingGatewayClient.new(endpoint: "http://agent.test/webhooks/task-briefing", token: "secret")
      result = client.call("gateway" => "task_briefing", "tasks" => [])

      assert_equal "Ready", result["headline"]
    end

    expected_signature = OpenSSL::HMAC.hexdigest("SHA256", "secret", captured_request.body)
    assert_equal "sha256=#{expected_signature}", captured_request["X-Hub-Signature-256"]
    assert_equal expected_signature, captured_request["X-Webhook-Signature"]
    assert_nil captured_request["Authorization"]
  end

  test "returns parsed acknowledgement for accepted async gateway responses" do
    response = Net::HTTPAccepted.new("1.1", "202", "Accepted")
    response.instance_variable_set(:@read, true)
    response.body = JSON.generate("status" => "accepted", "route" => "task-briefing")

    http_start = lambda do |*, &block|
      block.call(FakeHttp.new(response))
    end

    with_net_http_start(http_start) do
      client = Tasks::BriefingGatewayClient.new(endpoint: "http://agent.test/webhooks/task-briefing", token: "secret")

      assert_equal({ "status" => "accepted", "route" => "task-briefing" }, client.call("gateway" => "task_briefing", "tasks" => []))
    end
  end

  test "uses openai style request and parses chat completion content" do
    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = JSON.generate(
      "choices" => [
        {
          "message" => {
            "content" => JSON.generate(
              "headline" => "Opening task is overdue",
              "next_action" => "Check sanitizer buckets now.",
              "priority_items" => [
                {
                  "title" => "Check sanitizer buckets",
                  "status" => "late",
                  "due_label" => "8:00 AM",
                  "why_it_matters" => "Sanitizer needs to be verified."
                }
              ]
            )
          }
        }
      ]
    )
    captured_request = nil

    http_start = lambda do |*, &block|
      block.call(FakeHttp.new(response) { |request| captured_request = request })
    end

    with_net_http_start(http_start) do
      client = Tasks::BriefingGatewayClient.new(endpoint: "http://agent.test/v1/chat/completions", token: "secret", timeout_seconds: 60)
      result = client.call("gateway" => "task_briefing", "tasks" => [ { "title" => "Check sanitizer buckets" } ])

      assert_equal "Opening task is overdue", result["headline"]
      assert_equal "Check sanitizer buckets now.", result["next_action"]
    end

    request_body = JSON.parse(captured_request.body)
    assert_equal "Bearer secret", captured_request["Authorization"]
    assert_nil captured_request["X-Hub-Signature-256"]
    assert_equal "hermes-task-briefing", request_body["model"]
    assert_equal false, request_body["stream"]
    assert_match "Return ONLY valid JSON", request_body.dig("messages", 0, "content")
    assert_match "Check sanitizer buckets", request_body.dig("messages", 0, "content")
  end

  private

  def with_net_http_start(replacement)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, replacement)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  class FakeHttp
    def initialize(response, &capture)
      @response = response
      @capture = capture
    end

    def request(request)
      @capture&.call(request)
      @response
    end
  end
end
