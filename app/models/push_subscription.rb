# A single browser/device that has opted in to Web Push notifications.
#
# Created by the service-worker subscribe flow (see PushSubscriptionsController
# and the push_subscriptions Stimulus controller). Delivery is handled here so
# callers never touch the web-push gem directly:
#
#   user.push_subscriptions.notify_all(title: "Prep due", body: "...", url: "/tasks")
#
# Triggering notifications from real events (task reminders, low stock) is
# intentionally NOT wired up yet — this model is the plumbing those triggers
# will call.
class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, :auth_key, presence: true

  # Deliver one notification to every device a relation covers, pruning any that
  # the push service reports as gone. Use on an association:
  #   user.push_subscriptions.notify_all(...)
  def self.notify_all(**payload)
    find_each { |subscription| subscription.notify(**payload) }
  end

  # Push a single notification to this one device.
  #
  # The web-push gem encrypts the payload with the keys the browser gave us and
  # signs the request with our VAPID key. If the push service says the
  # subscription is gone (404/410), it's dead — delete the row so we stop
  # trying. Returns true when handed off to the push service, false otherwise.
  def notify(title:, body:, url: "/", tag: nil)
    return false unless WebPushConfig.configured?

    WebPush.payload_send(
      message: { title: title, body: body, url: url, tag: tag }.compact.to_json,
      endpoint: endpoint,
      p256dh: p256dh_key,
      auth: auth_key,
      vapid: {
        public_key: WebPushConfig.public_key,
        private_key: WebPushConfig.private_key,
        subject: WebPushConfig.subject
      },
      urgency: "high"
    )
    true
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    destroy
    false
  end
end
