class NormalizationReview < ApplicationRecord
  STATUSES = %w[pending resolved ignored].freeze

  belongs_to :receipt_line_item
  belongs_to :product, optional: true

  validates :issue_type, :description, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :recent, -> { order(created_at: :desc) }
end
