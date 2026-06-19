module PhotoAssets
  class AiTaggingJob < ApplicationJob
    queue_as :background

    def perform(photo_asset_id)
      return unless AiTagger.configured?

      asset = PhotoAsset.find_by(id: photo_asset_id)
      return if asset.nil? || asset.ai_tagged_at.present?

      AiTagger.new.tag!(asset)
    end
  end
end
