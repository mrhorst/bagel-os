class PhotoAssetsController < ApplicationController
  require_module_access :marketing

  SCOPES = (%w[all] + PhotoAsset::STATUSES).freeze

  before_action :load_asset, only: %i[show update destroy treat]

  def index
    @scope = SCOPES.include?(params[:scope]) ? params[:scope] : "all"
    @counts = PhotoAsset.group(:status).count
    @assets = assets_for(@scope).with_attached_photo.recent_first
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
      redirect_to photo_assets_path(scope: "unreviewed"),
        notice: "#{created} #{"photo".pluralize(created)} added to the library."
    else
      redirect_to new_photo_asset_path,
        alert: "Couldn't save: #{failed.to_sentence}. #{created} other #{"photo".pluralize(created)} saved."
    end
  end

  def show
  end

  def update
    attrs = params.require(:photo_asset).permit(:status, :caption, :notes)
    if attrs[:status].present? && attrs[:status] != @asset.status
      @asset.assign_attributes(reviewed_by: Current.user, reviewed_at: Time.current, reviewed_via: "manual")
    end

    if @asset.update(attrs)
      redirect_to photo_asset_path(@asset), notice: "Photo updated."
    else
      redirect_to photo_asset_path(@asset), alert: @asset.errors.full_messages.to_sentence
    end
  end

  def destroy
    @asset.destroy!
    redirect_to photo_assets_path, notice: "Photo deleted."
  end

  def treat
    unless PhotoAssets::AiTreatment.configured?
      redirect_to photo_asset_path(@asset), alert: "AI treatment isn't configured. Set GEMINI_API_KEY first."
      return
    end

    PhotoAssets::TreatmentJob.perform_later(@asset.id)
    redirect_to photo_asset_path(@asset), notice: "Treatment queued — the edited copy will appear here shortly."
  end

  def ai_review
    unless PhotoAssets::AiReviewer.configured?
      redirect_to photo_assets_path, alert: "AI review isn't configured. Set MARKETING_PHOTO_AGENT_GATEWAY_URL first."
      return
    end

    queued = 0
    PhotoAsset.with_status("unreviewed").where(reviewed_at: nil).find_each do |asset|
      PhotoAssets::AiReviewJob.perform_later(asset.id)
      queued += 1
    end

    redirect_to photo_assets_path(scope: "unreviewed"),
      notice: queued.zero? ? "Nothing to review." : "AI review queued for #{queued} #{"photo".pluralize(queued)}."
  end

  private

  def load_asset
    @asset = PhotoAsset.find(params[:id])
  end

  def assets_for(scope)
    scope == "all" ? PhotoAsset.all : PhotoAsset.with_status(scope)
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
