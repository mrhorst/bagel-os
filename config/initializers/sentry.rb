# Be sure to restart your server when you modify this file.
#
# Production error and performance monitoring. Events are reported to a
# self-hosted, Sentry-API-compatible GlitchTip instance (see
# docs/deployment/observability.md). Reporting stays OFF unless SENTRY_DSN is
# set, so development and test never phone home and the test suite needs no
# network access.
#
# PRIVACY: this app handles real restaurant operational data. We never opt in to
# Sentry's default PII capture, and Observability::SentryScrubber re-applies the
# app's parameter filter as a second layer. Keep both in place.

if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = Rails.env.to_s

    # Tie every event to the deployed commit so the triage agent knows exactly
    # which code produced an error. Kamal exposes the version as KAMAL_VERSION.
    config.release = ENV["SENTRY_RELEASE"].presence || ENV["KAMAL_VERSION"].presence

    config.breadcrumbs_logger = [ :active_support_logger ]

    # --- Privacy guards (see SentryScrubber) ---
    config.send_default_pii = false
    config.before_send = Observability::SentryScrubber.new

    # Capture every error; sample a slice of performance traces to keep volume sane.
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f

    # Routing/404/CSRF noise isn't an actionable code defect — don't page the agent on it.
    config.excluded_exceptions += %w[
      ActionController::RoutingError
      ActiveRecord::RecordNotFound
      ActionController::InvalidAuthenticityToken
    ]
  end
end
