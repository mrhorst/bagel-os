module PhotoAssets
  class AiDescriptionJob < ApplicationJob
    queue_as :background

    def perform(photo_asset_id)
      return unless AiDescriber.configured?

      asset = PhotoAsset.find_by(id: photo_asset_id)
      return if asset.nil?

      AiDescriber.new.describe!(asset)
    end
  end
end
