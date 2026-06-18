class PhotoAssetTaggingsController < ApplicationController
  require_module_access :marketing

  before_action :load_asset

  # Add a tag by hand — lands confirmed immediately.
  def create
    tag = Tag.active.find(params[:tag_id])
    tagging = @asset.taggings.find_or_initialize_by(tag: tag)
    tagging.source = "manual" if tagging.new_record?
    tagging.update!(confirmed_at: Time.current, created_by: Current.user)

    redirect_to photo_asset_path(@asset), notice: "Tagged #{tag.name}."
  end

  # Confirm an AI suggestion.
  def confirm
    tagging = @asset.taggings.find(params[:id])
    tagging.update!(confirmed_at: Time.current, created_by: tagging.created_by || Current.user)

    redirect_to photo_asset_path(@asset), notice: "Confirmed #{tagging.tag.name}."
  end

  # Remove a tag, or dismiss a pending suggestion.
  def destroy
    tagging = @asset.taggings.find(params[:id])
    tagging.destroy!

    redirect_to photo_asset_path(@asset), notice: "Removed #{tagging.tag.name}."
  end

  private

  def load_asset
    @asset = PhotoAsset.find(params[:photo_asset_id])
  end
end
