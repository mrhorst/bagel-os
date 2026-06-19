class PhotoAsset < ApplicationRecord
  # Tagging lifecycle: pending (no tags yet) -> needs_review (AI suggested tags
  # awaiting a human) -> tagged (at least one confirmed tag, nothing pending).
  STATUSES = %w[pending needs_review tagged].freeze

  has_paper_trail ignore: %i[updated_at]

  has_one_attached :photo

  belongs_to :uploaded_by, class_name: "User", optional: true

  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings
  has_many :confirmed_taggings, -> { confirmed }, class_name: "Tagging", inverse_of: :photo_asset
  has_many :confirmed_tags, through: :confirmed_taggings, source: :tag

  validates :status, inclusion: { in: STATUSES }
  validate :photo_must_be_an_attached_image

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :with_status, ->(status) { where(status: status) }

  # Photos carrying a confirmed instance of the given tag slug.
  scope :tagged_with, ->(slug) {
    joins(taggings: :tag).where(tags: { slug: slug }).where.not(taggings: { confirmed_at: nil }).distinct
  }

  # Free-text match across caption, notes, and tag names.
  scope :search, ->(query) {
    term = "%#{query.to_s.strip.downcase}%"
    left_joins(taggings: :tag)
      .where("LOWER(photo_assets.caption) LIKE :q OR LOWER(photo_assets.notes) LIKE :q OR LOWER(tags.name) LIKE :q", q: term)
      .distinct
  }

  after_create_commit :enqueue_ai_tagging

  def status_label
    status == "pending" ? "Untagged" : status.humanize
  end

  # Recompute the cached status from the current set of taggings. Uses
  # update_column to skip callbacks/validations — this is a derived cache, not
  # a user edit, so it shouldn't spawn a PaperTrail version or re-fire hooks.
  def refresh_status!
    desired =
      if taggings.pending.exists? then "needs_review"
      elsif taggings.confirmed.exists? then "tagged"
      else "pending"
      end
    update_column(:status, desired) unless status == desired
  end

  private

  def enqueue_ai_tagging
    PhotoAssets::AiTaggingJob.perform_later(id) if PhotoAssets::AiTagger.configured?
  end

  def photo_must_be_an_attached_image
    if !photo.attached?
      errors.add(:photo, "must be attached")
    elsif !photo.blob.content_type.to_s.start_with?("image/")
      errors.add(:photo, "must be an image")
    end
  end
end
