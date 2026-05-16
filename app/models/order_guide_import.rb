class OrderGuideImport < ApplicationRecord
  GUIDE_TYPES = %w[daily weekly].freeze
  STATUSES = %w[pending imported failed skipped].freeze

  has_many :order_guide_items, dependent: :destroy

  validates :source_filename, :guide_type, :file_checksum, :imported_at, :status, presence: true
  validates :guide_type, inclusion: { in: GUIDE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :file_checksum, uniqueness: true

  scope :imported, -> { where(status: "imported") }
  scope :recent_first, -> { order(imported_at: :desc, id: :desc) }
end
