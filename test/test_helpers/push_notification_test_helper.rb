module PushNotificationTestHelper
  # minitest ships no mock/stub, so swap a singleton method for the duration of
  # the block and restore it afterwards (same approach as PushSubscriptionTest).
  def stub_method(receiver, name, replacement)
    original = receiver.method(name)
    receiver.singleton_class.send(:define_method, name, replacement)
    yield
  ensure
    receiver.singleton_class.send(:define_method, name, original)
  end

  # Run the block with Web Push "configured", capturing every notification that
  # would be sent. Returns an array of decoded { title:, body:, url:, tag: }
  # payload hashes (symbol keys) in delivery order.
  def capture_push_notifications
    sent = []
    recorder = ->(**args) { sent << JSON.parse(args[:message]).symbolize_keys }

    stub_method(WebPushConfig, :configured?, -> { true }) do
      stub_method(WebPush, :payload_send, recorder) do
        yield
      end
    end

    sent
  end
end
