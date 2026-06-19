# Web Push (VAPID) configuration.
#
# VAPID keys identify THIS server to the browser push services (Google FCM,
# Mozilla, Apple) so a notification can be proven to come from us. We generate
# one ECDSA P-256 key pair per deployment — never per user.
#
#   bin/rails web_push:generate_keys   # prints a fresh pair
#
# The PRIVATE key is a secret. This is the generic, public repo, so keys are
# read from per-deployment config and must never be committed here:
#
#   * Rails credentials:  web_push.public_key / web_push.private_key
#   * or environment:     VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY
#
# When no keys are configured, push is simply disabled (`configured?` is false)
# and the UI hides the opt-in — the rest of the app is unaffected.
module WebPushConfig
  class << self
    def public_key
      credentials&.dig(:public_key).presence || ENV["VAPID_PUBLIC_KEY"].presence
    end

    def private_key
      credentials&.dig(:private_key).presence || ENV["VAPID_PRIVATE_KEY"].presence
    end

    # Surfaced in the VAPID JWT `sub` claim so a push service can reach the
    # operator about a misbehaving sender. Must be a mailto: or https: URL.
    def subject
      ENV["VAPID_SUBJECT"].presence || "mailto:ops@example.com"
    end

    def configured?
      public_key.present? && private_key.present?
    end

    private

    def credentials
      Rails.application.credentials.web_push
    end
  end
end
