module Notifications
  # Overnight window during which recurring push notifications stay silent so a
  # task that goes late at 2 AM doesn't buzz phones in the dark. Time-based
  # senders (the late-task sweep, the daily digests) check this and simply skip
  # the run; because they're driven by persisted "already notified" state, a
  # condition that arises during quiet hours is delivered on the first run once
  # the window lifts — nothing is lost, just deferred.
  #
  # Edge-triggered, user-initiated notifications (e.g. a follow-up assigned to
  # you) intentionally do NOT consult quiet hours — they're rare, deliberate,
  # and expected by the recipient.
  module QuietHours
    START_HOUR = 22 # 10 PM, inclusive
    END_HOUR   = 6  # 6 AM, exclusive

    # Quiet when the local hour is in [START_HOUR, 24) ∪ [0, END_HOUR).
    def self.active?(time = Time.current)
      hour = time.in_time_zone.hour
      hour >= START_HOUR || hour < END_HOUR
    end
  end
end
