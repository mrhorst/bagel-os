class PhotoAsset < ApplicationRecord
  STATUSES = %w[unreviewed approved needs_work rejected].freeze

  has_paper_trail ignore: %i[updated_at]

  has_one_attached :photo

  belongs_to :uploaded_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validate :photo_must_be_an_attached_image

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :with_status, ->(status) { where(status: status) }

  def status_label
    status.humanize
  end

  private

  def photo_must_be_an_attached_image
    if !photo.attached?
      errors.add(:photo, "must be attached")
    elsif !photo.blob.content_type.to_s.start_with?("image/")
      errors.add(:photo, "must be an image")
    end
  end
end
