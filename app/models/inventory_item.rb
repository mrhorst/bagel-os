class InventoryItem < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :inventory_section, optional: true
  belongs_to :preferred_supplier, class_name: "Supplier", optional: true

  has_many :inventory_count_lines, dependent: :destroy
  has_many :inventory_counts, through: :inventory_count_lines
  has_many :order_guide_items, dependent: :nullify

  before_validation :assign_key

  validates :name, presence: true
  validates :key, presence: true, uniqueness: true
  validates :guide_frequency, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { left_joins(:inventory_section).order("inventory_sections.position ASC", :position, :name) }
  scope :needs_review, -> { where(needs_review: true) }

  def self.key_for(value)
    value.to_s.downcase.gsub(/&/, " and ").gsub(/[^a-z0-9]+/, " ").squish.parameterize
  end

  def latest_count_line
    inventory_count_lines.joins(:inventory_count).order("inventory_counts.counted_at DESC", "inventory_count_lines.id DESC").first
  end

  def quantity_on_hand
    latest_count_line&.quantity_on_hand
  end

  def linked_product_name
    product&.canonical_name || "Unlinked"
  end

  def latest_price
    product&.latest_observation&.package_price
  end

  def total_spend
    product&.price_observations&.sum(:line_total) || 0
  end

  def purchase_count
    product&.price_observations&.count || 0
  end

  def guide_frequency_label
    guide_frequency.to_s.humanize
  end

  def merge_guide_frequency!(new_frequency)
    new_value =
      if guide_frequency == "manual" || guide_frequency.blank?
        new_frequency
      elsif guide_frequency == new_frequency
        guide_frequency
      else
        "both"
      end

    update!(guide_frequency: new_value) if new_value != guide_frequency
  end

  private

  def assign_key
    self.key = self.class.key_for(name) if key.blank? && name.present?
  end
end
