class PhotoAssetDescriptionsController < ApplicationController
  require_module_access :marketing

  # Kick off AI marketing copy for one photo. The result lands asynchronously
  # in the photo's suggestion fields.
  def create
    asset = PhotoAsset.find(params[:id])

    unless PhotoAssets::AiDescriber.configured?
      return redirect_to photo_asset_path(asset), alert: "AI copy isn't set up for this install yet."
    end

    PhotoAssets::AiDescriptionJob.perform_later(asset.id)
    redirect_to photo_asset_path(asset), notice: "Writing a caption, hashtags, and alt text — refresh in a moment."
  end
end
