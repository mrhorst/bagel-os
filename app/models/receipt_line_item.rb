class ReceiptLineItem < ApplicationRecord
  LINE_TYPES = %w[item coupon adjustment].freeze

  belongs_to :receipt
  belongs_to :supplier
  belongs_to :import_batch
  belongs_to :product, optional: true
  belongs_to :case_pack, class_name: "SupplierProductPack", optional: true
  has_one :price_observation, dependent: :destroy
  has_many :normalization_reviews, dependent: :destroy

  validates :line_number, :line_type, :raw_name, :row_checksum, presence: true
  validates :line_number, uniqueness: { scope: :import_batch_id }
  validates :line_type, inclusion: { in: LINE_TYPES }

  scope :items, -> { where(line_type: "item") }
  scope :needs_review, -> { where(needs_review: true) }

  def display_quantity
    case purchase_kind
    when "mixed"
      "#{compact_quantity(unit_quantity_value)} units / #{compact_quantity(case_quantity_value)} cases"
    when "unit"
      "#{compact_quantity(unit_quantity_value)} units"
    when "case"
      "#{compact_quantity(case_quantity_value)} cases"
    else
      quantity.presence || raw_quantity.presence || raw_case_quantity
    end
  end

  def purchase_kind
    unit_present = unit_quantity_value.to_d.positive?
    case_present = case_quantity_value.to_d.positive?

    return "mixed" if unit_present && case_present
    return "unit" if unit_present
    return "case" if case_present

    "unknown"
  end

  private

  def compact_quantity(value)
    value.to_d.to_s("F").sub(/\.?0+\z/, "")
  end

  def unit_quantity_value
    unit_quantity.nil? ? raw_quantity : unit_quantity
  end

  def case_quantity_value
    case_quantity.nil? ? raw_case_quantity : case_quantity
  end
end
