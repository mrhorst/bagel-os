class SharesController < ApplicationController
  require_module_access :marketing

  before_action :set_collection

  # Mint a public link for the collection, reusing an existing active one so
  # clicking twice doesn't pile up duplicate links.
  def create
    @collection.shares.active.first || @collection.shares.create!(created_by: Current.user)
    redirect_to collection_path(@collection), notice: "Share link ready — anyone with it can view and download."
  end

  # Revoke a link so its URL stops working.
  def destroy
    @collection.shares.find(params[:id]).revoke!
    redirect_to collection_path(@collection), notice: "Share link revoked."
  end

  private

  def set_collection
    @collection = Collection.find(params[:collection_id])
  end
end
