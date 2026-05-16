class Product < ApplicationRecord
  belongs_to :supplier
  belongs_to :product_category, optional: true
  has_many :receipt_line_items, dependent: :nullify
  has_many :product_aliases, dependent: :destroy
  has_many :price_observations, dependent: :destroy
  has_many :inventory_items, dependent: :nullify
  has_many :supplier_product_packs, dependent: :nullify

  validates :canonical_name, presence: true
  validates :supplier_sku, uniqueness: { scope: :supplier_id, allow_blank: true }

  scope :active, -> { where(active: true) }
  scope :needs_review, -> { where(needs_review: true) }
  scope :by_name, -> { order(:canonical_name) }

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

  def price_intelligence
    Purchasing::PriceIntelligence.new
  end
end
