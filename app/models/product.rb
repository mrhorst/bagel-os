class Product < ApplicationRecord
  # How a product is used: by count (eggs), by weight (corned beef hash), or by
  # volume. Left blank when unknown — never guessed.
  UNIT_BASES = %w[count weight volume].freeze

  belongs_to :supplier
  belongs_to :product_category, optional: true
  has_many :receipt_line_items, dependent: :nullify
  has_many :product_aliases, dependent: :destroy
  has_many :price_observations, dependent: :destroy
  has_many :inventory_items, dependent: :nullify
  has_many :supplier_product_packs, dependent: :nullify

  validates :canonical_name, presence: true
  validates :supplier_sku, uniqueness: { scope: :supplier_id, allow_blank: true }
  validates :unit_basis, inclusion: { in: UNIT_BASES }, allow_blank: true
  validates :each_weight_value, numericality: { greater_than: 0 }, allow_nil: true
  validate :each_weight_is_complete_and_weighted

  scope :active, -> { where(active: true) }
  scope :needs_review, -> { where(needs_review: true) }
  scope :by_name, -> { order(:canonical_name) }

  def count_based?
    unit_basis == "count"
  end

  def weight_based?
    unit_basis == "weight"
  end

  def volume_based?
    unit_basis == "volume"
  end

  # The average weight of one "each" expressed in grams, or nil when the bridge
  # isn't set. This is what lets a counted product (e.g. eggs) take part in a
  # recipe's weight total and in count↔weight costing.
  def each_weight_in_grams
    return if each_weight_value.blank? || each_weight_unit.blank?

    Measurement::Units.convert(each_weight_value, from: each_weight_unit, to: "g")
  end

  def category_name
    product_category&.name || "Missing category"
  end

  def supplier_sku_summary
    skus = product_aliases.map(&:raw_sku).compact_blank.uniq
    return supplier_sku.presence || "n/a" if skus.empty?
    return skus.first if skus.one?

    "varies (#{skus.size})"
  end

  def variation_summaries
    price_intelligence.variation_summaries(self)
  end

  def latest_observation
    price_intelligence.latest_observation(self)
  end

  def price_stats
    price_intelligence.price_stats(self)
  end

  private

  # The each-weight bridge is all-or-nothing and must be a real weight: a value
  # without a unit (or the reverse) can't be used, and a non-weight unit like
  # "cup" would defeat the purpose of mapping a count onto a weight.
  def each_weight_is_complete_and_weighted
    return if each_weight_value.blank? && each_weight_unit.blank?

    if each_weight_value.blank? || each_weight_unit.blank?
      errors.add(:each_weight_unit, "and the average weight must be filled in together")
      return
    end

    unless Measurement::Units.dimension(each_weight_unit) == Measurement::Units::WEIGHT
      errors.add(:each_weight_unit, "must be a weight unit (g, kg, oz, lb)")
    end
  end

  def price_intelligence
    Purchasing::PriceIntelligence.new
  end
end
