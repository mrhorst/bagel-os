class PhotoAsset < ApplicationRecord
  STATUSES = %w[unreviewed approved needs_work rejected].freeze
  REVIEW_SOURCES = %w[manual ai].freeze

  has_paper_trail ignore: %i[updated_at]

  has_one_attached :photo
  has_one_attached :treated_photo

  belongs_to :uploaded_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :reviewed_via, inclusion: { in: REVIEW_SOURCES }, allow_nil: true
  validate :photo_must_be_an_attached_image

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :with_status, ->(status) { where(status: status) }

  after_create_commit :enqueue_ai_review

  def status_label
    status.humanize
  end

  def ai_reviewed?
    reviewed_via == "ai"
  end

  # The image to publish: the AI-treated copy when one exists, else the original.
  def publishable_photo
    treated_photo.attached? ? treated_photo : photo
  end

  private

  def enqueue_ai_review
    PhotoAssets::AiReviewJob.perform_later(id) if PhotoAssets::AiReviewer.configured?
  end

  def photo_must_be_an_attached_image
    if !photo.attached?
      errors.add(:photo, "must be attached")
    elsif !photo.blob.content_type.to_s.start_with?("image/")
      errors.add(:photo, "must be an image")
    end
  end
end
