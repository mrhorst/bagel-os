module Public
  # Public, login-free view of a shared collection, addressed only by its
  # share token. Revoked or expired tokens 404. Active Storage URLs are signed
  # and live outside app auth, so the images and per-photo downloads work for
  # external viewers (a designer, a printer) without an account.
  class SharedCollectionsController < ApplicationController
    allow_unauthenticated_access
    layout "public"

    before_action :set_share

    def show
      @collection = @share.collection
      @assets = @collection.photo_assets
        .with_attached_photo.includes(:confirmed_tags)
        .order("collection_memberships.position", "collection_memberships.id")
    end

    # Download the whole shared collection as a ZIP.
    def download
      assets = @share.collection.photo_assets.with_attached_photo.includes(confirmed_tags: []).recent_first
      send_data PhotoAssets::ZipBuilder.new(assets).bytes,
        filename: "collection-#{@share.collection.slug}.zip", type: "application/zip"
    end

    private

    def set_share
      @share = Share.find_by(token: params[:token])
      head :not_found unless @share&.usable?
    end
  end
end
