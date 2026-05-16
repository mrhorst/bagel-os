class ReceiptLineItem < ApplicationRecord
  LINE_TYPES = %w[item coupon adjustment].freeze

  belongs_to :receipt
  belongs_to :supplier
  belongs_to :import_batch
  belongs_to :product, optional: true
  has_one :price_observation, dependent: :destroy
  has_many :normalization_reviews, dependent: :destroy

  validates :line_number, :line_type, :raw_name, :row_checksum, presence: true
  validates :line_number, uniqueness: { scope: :import_batch_id }
  validates :line_type, inclusion: { in: LINE_TYPES }

  scope :items, -> { where(line_type: "item") }
  scope :needs_review, -> { where(needs_review: true) }

  def display_quantity
    quantity.presence || raw_quantity.presence || raw_case_quantity
  end
end
