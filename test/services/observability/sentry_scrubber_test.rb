require "test_helper"

module Observability
  class SentryScrubberTest < ActiveSupport::TestCase
    FakeRequest = Struct.new(:data, :cookies, :headers)
    FakeEvent = Struct.new(:request)

    test "filters sensitive params in the request body using a parameter filter" do
      event = FakeEvent.new(
        FakeRequest.new({ "password" => "hunter2", "quantity" => "5" }, nil, {})
      )

      scrub(event, filter: [ :password ])

      assert_equal "[FILTERED]", event.request.data["password"]
      assert_equal "5", event.request.data["quantity"]
    end

    test "drops cookies and sensitive headers but keeps benign ones" do
      event = FakeEvent.new(
        FakeRequest.new(
          {},
          "session=abc123",
          { "Authorization" => "Bearer secret", "Cookie" => "a=b", "Accept" => "*/*" }
        )
      )

      scrub(event)

      assert_nil event.request.cookies
      refute event.request.headers.key?("Authorization")
      refute event.request.headers.key?("Cookie")
      assert_equal "*/*", event.request.headers["Accept"]
    end

    test "returns the event untouched when it carries no request" do
      event = FakeEvent.new(nil)

      assert_same event, SentryScrubber.new.call(event, nil)
    end

    private

    def scrub(event, filter: [])
      parameter_filter = ActiveSupport::ParameterFilter.new(filter)
      SentryScrubber.new(parameter_filter: parameter_filter).call(event, nil)
    end
  end
end
