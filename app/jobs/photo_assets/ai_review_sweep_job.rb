module PhotoAssets
  # Safety net for the per-upload review hook: picks up photos that are still
  # unreviewed (e.g. uploaded while the API key was missing or a review
  # errored) and queues them again.
  class AiReviewSweepJob < ApplicationJob
    queue_as :background

    def perform
      return unless AiReviewer.configured?

      PhotoAsset.with_status("unreviewed")
        .where(reviewed_at: nil)
        .where(created_at: ..5.minutes.ago)
        .find_each { |asset| AiReviewJob.perform_later(asset.id) }
    end
  end
end
