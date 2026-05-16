class SupplierProductPack < ApplicationRecord
  SOURCES = %w[manual restaurant_depot_catalog receipt_text vendor_sheet other].freeze
  PURCHASE_KINDS = %w[case].freeze

  belongs_to :supplier
  belongs_to :product, optional: true
  has_many :receipt_line_items, foreign_key: :case_pack_id, dependent: :nullify
  has_many :price_observations, foreign_key: :case_pack_id, dependent: :nullify

  validates :purchase_kind, inclusion: { in: PURCHASE_KINDS }
  validates :source, inclusion: { in: SOURCES }
  validates :units_per_case, numericality: { greater_than: 0 }
  validates :inner_unit_label, presence: true
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validate :has_matching_scope
  validate :standard_unit_requires_inner_package_size

  scope :approved, -> { where(approved: true) }
  scope :case_packs, -> { where(purchase_kind: "case") }

  def inner_unit_price_for(line_total:, case_quantity:)
    inner_quantity = inner_quantity_for(case_quantity: case_quantity)
    return if inner_quantity.blank? || inner_quantity.zero?

    (line_total.to_d / inner_quantity).round(4)
  end

  def inner_quantity_for(case_quantity:)
    return if case_quantity.blank?

    case_quantity.to_d * units_per_case.to_d
  end

  def standard_quantity_for(case_quantity:)
    return if inner_package_size.blank? || standard_unit.blank?

    inner_quantity_for(case_quantity: case_quantity).to_d * inner_package_size.to_d
  end

  private

  def has_matching_scope
    return if product_id.present? || raw_sku.present? || raw_name.present?

    errors.add(:base, "Add a product, raw SKU, or raw name so this case-pack fact can be matched safely.")
  end

  def standard_unit_requires_inner_package_size
    return if standard_unit.blank? || inner_package_size.present?

    errors.add(:inner_package_size, "is required when standard unit is present.")
  end
end
