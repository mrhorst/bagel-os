class ImportBatch < ApplicationRecord
  STATUSES = %w[pending imported skipped failed].freeze

  belongs_to :supplier
  has_one :receipt, dependent: :destroy
  has_many :receipt_line_items, dependent: :destroy

  validates :source_filename, :file_checksum, :imported_at, presence: true
  validates :file_checksum, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(imported_at: :desc, created_at: :desc) }
end
