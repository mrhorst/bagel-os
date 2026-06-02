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
