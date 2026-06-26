module Public
  # Public, login-free view of a shared collection, addressed only by its
  # share token. Revoked or expired tokens render a friendly "link unavailable"
  # page with a 404 status. Active Storage URLs are signed and live outside app
  # auth, so the images and per-photo downloads work for external viewers (a
  # designer, a printer) without an account.
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
      render_unavailable unless @share&.usable?
    end

    # A revoked, expired, or unknown token still must not resolve — but the
    # viewer is an external recipient with no account, so a bare `head
    # :not_found` strands them on a blank browser error page with no idea what
    # happened or what to do. Render a branded "link unavailable" page (still
    # 404) so the dead link explains itself and points them back to whoever
    # shared it, matching the friendly error surfaces the rest of the app shows.
    def render_unavailable
      render "unavailable", status: :not_found
    end
  end
end
