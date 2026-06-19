class PhotoAssetExportsController < ApplicationController
  require_module_access :marketing

  # GET — download a whole collection, or the current library filter, as a ZIP.
  def show
    if (collection = Collection.find_by(id: params[:collection_id]))
      send_zip(collection.photo_assets, "collection-#{collection.slug}")
    else
      send_zip(filtered_assets, "photo-library")
    end
  end

  # POST — download an explicit multi-select of photos as a ZIP.
  def create
    ids = Array(params[:photo_asset_ids]).map(&:to_i).reject(&:zero?)
    if ids.empty?
      return redirect_back fallback_location: photo_assets_path, alert: "Select at least one photo to download."
    end

    send_zip(PhotoAsset.where(id: ids), "photo-selection")
  end

  private

  def filtered_assets
    PhotoAsset.library(
      status: PhotoAssetsController::SCOPE_STATUS[params[:scope]],
      tag_slug: params[:tag],
      query: params[:q],
      favorites: params[:favorites].present?
    )
  end

  def send_zip(assets, basename)
    assets = assets.with_attached_photo.includes(confirmed_tags: []).recent_first
    if assets.none?
      return redirect_back fallback_location: photo_assets_path, alert: "No photos to download."
    end

    send_data PhotoAssets::ZipBuilder.new(assets).bytes,
      filename: "#{basename}.zip", type: "application/zip"
  end
end
