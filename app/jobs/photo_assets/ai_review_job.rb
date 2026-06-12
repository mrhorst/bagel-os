module PhotoAssets
  class AiReviewJob < ApplicationJob
    queue_as :background

    def perform(photo_asset_id)
      return unless AiReviewer.configured?

      asset = PhotoAsset.find_by(id: photo_asset_id)
      return if asset.nil? || asset.reviewed_at.present? || asset.status != "unreviewed"

      verdict = AiReviewer.new.review!(asset)
      return if verdict.nil?

      if verdict["treatment_recommended"] && asset.status != "rejected" && AiTreatment.configured?
        TreatmentJob.perform_later(asset.id)
      end
    end
  end
end
