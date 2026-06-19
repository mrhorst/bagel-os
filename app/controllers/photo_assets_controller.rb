class PhotoAssetsController < ApplicationController
  require_module_access :marketing

  # Library filters. "untagged" maps to the "pending" status (no tags yet).
  SCOPES = %w[all needs_review tagged untagged].freeze
  SCOPE_STATUS = { "needs_review" => "needs_review", "tagged" => "tagged", "untagged" => "pending" }.freeze

  before_action :load_asset, only: %i[show update destroy toggle_favorite]

  def index
    @scope = SCOPES.include?(params[:scope]) ? params[:scope] : "all"
    @query = params[:q].to_s.strip
    @favorites_only = params[:favorites].present?
    @tags = Tag.active.ordered
    @active_tag = @tags.find { |tag| tag.slug == params[:tag] }
    @collections = Collection.ordered
    @counts = status_counts

    @assets = PhotoAsset
      .library(status: SCOPE_STATUS[@scope], tag_slug: @active_tag&.slug, query: @query, favorites: @favorites_only)
      .with_attached_photo.includes(:confirmed_tags).recent_first
  end

  def new
  end

  def create
    uploads = incoming_photos

    if uploads.empty?
      redirect_to new_photo_asset_path, alert: "Choose at least one photo."
      return
    end

    created, failed = save_uploads(uploads)

    if failed.empty?
      redirect_to photo_assets_path,
        notice: "#{created} #{"photo".pluralize(created)} added to the library."
    else
      redirect_to new_photo_asset_path,
        alert: "Couldn't save: #{failed.to_sentence}. #{created} other #{"photo".pluralize(created)} saved."
    end
  end

  def show
    @suggestions = @asset.taggings.pending.includes(:tag).sort_by { |t| t.tag.name }
    @applied = @asset.taggings.confirmed.includes(:tag).sort_by { |t| t.tag.name }
    @available_tags = Tag.active.ordered.where.not(id: @asset.tag_ids)
    @tags_vocabulary_empty = !Tag.active.exists?
    @memberships = @asset.collection_memberships.includes(:collection).sort_by { |m| m.collection.name }
    @available_collections = Collection.ordered.where.not(id: @asset.collection_ids)
  end

  def update
    if @asset.update(params.require(:photo_asset).permit(:caption, :notes, :alt_text, :hashtags))
      redirect_to photo_asset_path(@asset), notice: "Photo updated."
    else
      redirect_to photo_asset_path(@asset), alert: @asset.errors.full_messages.to_sentence
    end
  end

  def destroy
    @asset.destroy!
    redirect_to photo_assets_path, notice: "Photo deleted."
  end

  # Star / unstar a photo as a team favorite ("hero" shot).
  def toggle_favorite
    @asset.update_column(:favorite, !@asset.favorite)
    redirect_back fallback_location: photo_asset_path(@asset),
      notice: @asset.favorite? ? "Added to favorites." : "Removed from favorites."
  end

  private

  def load_asset
    @asset = PhotoAsset.find(params[:id])
  end

  def status_counts
    by_status = PhotoAsset.group(:status).count
    {
      "all" => by_status.values.sum,
      "needs_review" => by_status.fetch("needs_review", 0),
      "tagged" => by_status.fetch("tagged", 0),
      "untagged" => by_status.fetch("pending", 0)
    }
  end

  # Two inputs feed the same library: a single capture="environment" field
  # (mobile camera) and a multiple-select library field.
  def incoming_photos
    raw = params[:photo_asset] || {}
    uploads = Array(raw[:photos]).select { |upload| upload.respond_to?(:original_filename) }
    camera = raw[:camera_photo]
    uploads << camera if camera.respond_to?(:original_filename)
    uploads
  end

  def save_uploads(uploads)
    created = 0
    failed = []
    uploads.each do |upload|
      asset = PhotoAsset.new(photo: upload, uploaded_by: Current.user)
      asset.save ? created += 1 : failed << upload.original_filename
    end
    [ created, failed ]
  end
end
