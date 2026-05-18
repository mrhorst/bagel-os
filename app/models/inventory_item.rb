class InventoryItem < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :inventory_section, optional: true
  belongs_to :preferred_supplier, class_name: "Supplier", optional: true

  has_many :inventory_count_lines, dependent: :destroy
  has_many :inventory_counts, through: :inventory_count_lines
  has_many :order_guide_items, dependent: :nullify
  has_many :order_guide_memberships, dependent: :destroy
  has_many :order_guides, through: :order_guide_memberships

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

  def primary_order_guide_membership
    order_guide_memberships.active.primary_guide.includes(:order_guide).first
  end

  def primary_order_guide
    primary_order_guide_membership&.order_guide
  end

  def order_guide_label
    primary_order_guide&.name || guide_frequency_label
  end

  def additional_order_guides
    order_guide_memberships
      .active
      .includes(:order_guide)
      .reject(&:primary_guide?)
      .map(&:order_guide)
      .sort_by { |guide| [ guide.position, guide.name ] }
  end

  def assign_primary_order_guide!(order_guide)
    transaction do
      order_guide_memberships.active.primary_guide.update_all(primary_guide: false, updated_at: Time.current)

      return if order_guide.blank?

      membership = order_guide_memberships.find_or_initialize_by(order_guide: order_guide)
      membership.active = true
      membership.primary_guide = true
      membership.position = position if membership.position.blank? || membership.position.zero?
      membership.save!
    end
  end

  def add_to_order_guide!(order_guide, primary: false, position: nil, notes: nil)
    membership = order_guide_memberships.find_or_initialize_by(order_guide: order_guide)
    membership.active = true
    membership.primary_guide = primary
    membership.position = position if position.present? || membership.position.blank?
    membership.notes = notes if notes.present?
    membership.save!
    membership
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
