require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @subscription = @user.push_subscriptions.create!(
      endpoint: "https://push.example.com/abc",
      p256dh_key: "p256dh",
      auth_key: "auth"
    )
  end

  test "requires a unique endpoint" do
    duplicate = @user.push_subscriptions.build(
      endpoint: @subscription.endpoint, p256dh_key: "x", auth_key: "y"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:endpoint], "has already been taken"
  end

  test "notify is a no-op when VAPID keys are not configured" do
    stub_method(WebPushConfig, :configured?, -> { false }) do
      assert_not @subscription.notify(title: "Hi", body: "There")
    end
  end

  test "notify hands the encrypted payload to the push service when configured" do
    sent = nil
    record_send = ->(**args) { sent = args }

    stub_method(WebPushConfig, :configured?, -> { true }) do
      stub_method(WebPush, :payload_send, record_send) do
        assert @subscription.notify(title: "Prep due", body: "Mise en place", url: "/tasks", tag: "t1")
      end
    end

    assert_equal @subscription.endpoint, sent[:endpoint]
    assert_equal @subscription.p256dh_key, sent[:p256dh]
    assert_equal @subscription.auth_key, sent[:auth]

    payload = JSON.parse(sent[:message])
    assert_equal "Prep due", payload["title"]
    assert_equal "/tasks", payload["url"]
    assert_equal "t1", payload["tag"]
  end

  test "notify deletes a subscription the push service reports as gone" do
    response = Struct.new(:body).new("Gone")
    raise_expired = ->(**_args) { raise WebPush::ExpiredSubscription.new(response, "push.example.com") }

    stub_method(WebPushConfig, :configured?, -> { true }) do
      stub_method(WebPush, :payload_send, raise_expired) do
        assert_not @subscription.notify(title: "x", body: "y")
      end
    end

    assert_not PushSubscription.exists?(@subscription.id)
  end

  test "notify_all delivers to every subscription in a relation" do
    @user.push_subscriptions.create!(
      endpoint: "https://push.example.com/def", p256dh_key: "p", auth_key: "a"
    )
    delivered = 0
    count_send = ->(**_args) { delivered += 1 }

    stub_method(WebPushConfig, :configured?, -> { true }) do
      stub_method(WebPush, :payload_send, count_send) do
        @user.push_subscriptions.notify_all(title: "x", body: "y")
      end
    end

    assert_equal 2, delivered
  end

  private

  # minitest 6 ships no mock/stub, so swap a singleton method for the duration
  # of the block and restore it afterwards.
  def stub_method(receiver, name, replacement)
    original = receiver.method(name)
    receiver.singleton_class.send(:define_method, name, replacement)
    yield
  ensure
    receiver.singleton_class.send(:define_method, name, original)
  end
end
