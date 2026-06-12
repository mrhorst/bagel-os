module PhotoAssets
  class TreatmentJob < ApplicationJob
    queue_as :background

    def perform(photo_asset_id)
      return unless AiTreatment.configured?

      asset = PhotoAsset.find_by(id: photo_asset_id)
      return if asset.nil?

      AiTreatment.new.treat!(asset)
    end
  end
end
