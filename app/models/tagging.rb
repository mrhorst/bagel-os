class Tagging < ApplicationRecord
  SOURCES = %w[ai manual].freeze

  belongs_to :photo_asset
  belongs_to :tag
  belongs_to :created_by, class_name: "User", optional: true

  validates :source, inclusion: { in: SOURCES }
  validates :tag_id, uniqueness: { scope: :photo_asset_id }

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :pending,   -> { where(confirmed_at: nil) }
  scope :ai,        -> { where(source: "ai") }
  scope :manual,    -> { where(source: "manual") }

  # Keep the owning asset's cached status in sync as taggings come and go.
  after_save    :refresh_photo_status
  after_destroy :refresh_photo_status

  def confirmed?
    confirmed_at.present?
  end

  private

  def refresh_photo_status
    photo_asset.refresh_status!
  end
end
