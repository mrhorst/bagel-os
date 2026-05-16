class Receipt < ApplicationRecord
  belongs_to :supplier
  belongs_to :import_batch
  has_many :receipt_line_items, dependent: :destroy

  validates :receipt_number, presence: true
  validates :receipt_number, uniqueness: { scope: :supplier_id }

  scope :chronological, -> { order(:purchased_at, :receipt_number) }
end
