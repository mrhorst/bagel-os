class PhotoAssetCropsController < ApplicationController
  require_module_access :marketing

  # Post-ready social crops. resize_to_fill centre-crops the original to fill
  # each platform's frame, so a download is ready to post without editing.
  FORMATS = {
    "square" => { dimensions: [ 1080, 1080 ], label: "Square" },
    "story"  => { dimensions: [ 1080, 1920 ], label: "Story" },
    "wide"   => { dimensions: [ 1920, 1080 ], label: "Wide" }
  }.freeze

  def show
    asset = PhotoAsset.find(params[:id])
    style = FORMATS[params[:style]]
    return head :not_found if style.nil?

    unless asset.photo.variable?
      return redirect_back fallback_location: photo_asset_path(asset),
        alert: "This image can't be cropped automatically — download the original instead."
    end

    variant = asset.photo.variant(resize_to_fill: style[:dimensions], format: :jpeg).processed
    send_data variant.download,
      filename: "photo-#{asset.id}-#{params[:style]}.jpg", type: "image/jpeg"
  end
end
