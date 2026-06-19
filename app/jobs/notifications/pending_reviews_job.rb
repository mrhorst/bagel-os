module Notifications
  # Once-a-day nudge that imported data has lines needing human resolution
  # (NormalizationReview in "pending"), so prices and units stay trustworthy.
  #
  # Reviews are created in bulk during imports, so a per-record callback would
  # spam one push per uncertain line. Instead this aggregates: it pushes only
  # when the pending pile has grown past what we last announced (tracked in a
  # NotificationDispatch ledger) and otherwise stays silent, ratcheting the
  # high-water mark down as reviews are cleared so a future import re-triggers.
  class PendingReviewsJob < ApplicationJob
    queue_as :background

    KIND = "normalization_reviews_pending".freeze

    def perform(now: Time.current)
      return unless WebPushConfig.configured?
      return if Notifications::QuietHours.active?(now)

      count = NormalizationReview.pending.count
      dispatch = NotificationDispatch.for(KIND)

      unless dispatch.announce?(count)
        dispatch.settle!(count)
        return
      end

      deliver(count)
      dispatch.record!(count, at: now)
    end

    private

    def deliver(count)
      Notifications::Audience.for_module(:normalization_reviews).find_each do |user|
        user.push_subscriptions.notify_all(
          title: "#{count} import #{'line'.pluralize(count)} #{count == 1 ? 'needs' : 'need'} review",
          body: "Some imported lines couldn't be matched or normalized confidently. Resolve them to keep prices accurate.",
          url: Rails.application.routes.url_helpers.normalization_reviews_path,
          tag: "normalization-reviews-pending"
        )
      end
    end
  end
end
