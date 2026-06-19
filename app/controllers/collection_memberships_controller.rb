class CollectionMembershipsController < ApplicationController
  require_module_access :marketing

  before_action :set_asset

  # Add the photo to a collection. Idempotent: adding it again is a no-op.
  def create
    collection = Collection.find(params[:collection_id])
    membership = collection.collection_memberships.find_or_initialize_by(photo_asset: @asset)
    membership.added_by ||= Current.user
    membership.position = next_position(collection) if membership.new_record?
    membership.save!

    redirect_back fallback_location: photo_asset_path(@asset), notice: "Added to #{collection.name}."
  end

  # Remove the photo from a collection.
  def destroy
    membership = @asset.collection_memberships.find(params[:id])
    name = membership.collection.name
    membership.destroy!

    redirect_back fallback_location: photo_asset_path(@asset), notice: "Removed from #{name}."
  end

  private

  def set_asset
    @asset = PhotoAsset.find(params[:photo_asset_id])
  end

  def next_position(collection)
    (collection.collection_memberships.maximum(:position) || 0) + 1
  end
end
