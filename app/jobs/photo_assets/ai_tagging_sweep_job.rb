module PhotoAssets
  # Safety net for the per-upload tagging hook: picks up photos that never got
  # an AI tagging pass (e.g. uploaded while the gateway was unreachable) and
  # queues them again.
  class AiTaggingSweepJob < ApplicationJob
    queue_as :background

    def perform
      return unless AiTagger.configured?

      PhotoAsset.where(ai_tagged_at: nil)
        .where(created_at: ..5.minutes.ago)
        .find_each { |asset| AiTaggingJob.perform_later(asset.id) }
    end
  end
end
