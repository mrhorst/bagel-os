module Observability
  # Last line of defense against leaking real restaurant, vendor, or staff data
  # into the (self-hosted) error tracker. Wired in as Sentry's +before_send+ hook,
  # but kept as a plain callable so the redaction rules can be unit-tested without
  # booting Sentry. See config/initializers/sentry.rb.
  #
  # Sentry already withholds request bodies, cookies, and client IPs while
  # +send_default_pii+ is false; this scrubber re-applies the app's own parameter
  # filter and strips auth/cookie headers so the two layers can't drift apart.
  class SentryScrubber
    SENSITIVE_HEADERS = %w[Authorization Cookie Set-Cookie X-Csrf-Token].freeze

    def initialize(parameter_filter: self.class.default_parameter_filter)
      @parameter_filter = parameter_filter
    end

    # Sentry calls this with (event, hint). Return the event to send it, or nil to drop it.
    def call(event, _hint = nil)
      request = event.request if event.respond_to?(:request)
      scrub_request(request) if request
      event
    end

    def self.default_parameter_filter
      ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end

    private

    attr_reader :parameter_filter

    def scrub_request(request)
      if request.respond_to?(:data) && request.data.is_a?(Hash)
        request.data = parameter_filter.filter(request.data)
      end

      request.cookies = nil if request.respond_to?(:cookies=)

      if request.respond_to?(:headers) && request.headers.is_a?(Hash)
        SENSITIVE_HEADERS.each { |header| request.headers.delete(header) }
      end

      request
    end
  end
end
