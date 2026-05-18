class InventoryCount < ApplicationRecord
  STATUSES = %w[draft completed].freeze

  belongs_to :inventory_section, optional: true
  belongs_to :order_guide, optional: true
  has_many :inventory_count_lines, dependent: :destroy
  has_many :inventory_items, through: :inventory_count_lines

  validates :source, :status, :counted_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(counted_at: :desc, id: :desc) }

  def completed?
    status == "completed"
  end
end
