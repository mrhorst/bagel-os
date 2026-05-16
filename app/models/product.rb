class Product < ApplicationRecord
  belongs_to :supplier
  belongs_to :product_category, optional: true
  has_many :receipt_line_items, dependent: :nullify
  has_many :product_aliases, dependent: :destroy
  has_many :price_observations, dependent: :destroy
  has_many :inventory_items, dependent: :nullify

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
    receipt_line_items.items.includes(:receipt, :import_batch).order(:raw_name, :raw_sku).group_by do |line_item|
      [ line_item.raw_name, line_item.raw_sku ]
    end.map do |(raw_name, raw_sku), lines|
      latest_line = lines.max_by { |line| [ line.receipt.purchased_at || line.created_at, line.id ] }

      {
        raw_name: raw_name,
        raw_sku: raw_sku,
        purchases_count: lines.size,
        total_spend: lines.sum { |line| line.line_total.to_d },
        first_purchased_at: lines.map { |line| line.receipt.purchased_at }.compact.min,
        last_purchased_at: lines.map { |line| line.receipt.purchased_at }.compact.max,
        latest_package_price: latest_line&.package_price,
        package_label: package_label_for(latest_line),
        needs_review: lines.any?(&:needs_review?)
      }
    end.sort_by { |summary| summary[:raw_name].to_s }
  end

  def latest_observation
    price_observations.order(observed_at: :desc, id: :desc).first
  end

  def price_stats
    observations = price_observations
    latest_standard_observation = observations.with_standard_unit_price.order(observed_at: :desc, id: :desc).first
    {
      latest_price: latest_observation&.package_price,
      average_price: observations.average(:package_price),
      lowest_price: observations.minimum(:package_price),
      highest_price: observations.maximum(:package_price),
      latest_standard_unit_price: latest_standard_observation&.standard_unit_price,
      average_standard_unit_price: observations.where.not(standard_unit_price: nil).average(:standard_unit_price),
      total_times_purchased: observations.count,
      total_quantity_purchased: observations.sum(:quantity),
      total_spend: observations.sum(:line_total),
      first_purchase_date: observations.minimum(:observed_at),
      last_purchase_date: observations.maximum(:observed_at)
    }
  end

  private

  def package_label_for(line_item)
    return "n/a" unless line_item

    size = line_item.parsed_package_size
    unit = line_item.parsed_unit_of_measure
    return "n/a" if size.blank? && unit.blank?
    return unit if size.blank?
    return size.to_d.round(4).to_s("F").sub(/\.?0+$/, "") if unit.blank?

    "#{size.to_d.round(4).to_s('F').sub(/\.?0+$/, '')} #{unit}"
  end
end
