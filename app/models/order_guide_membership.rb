class OrderGuideMembership < ApplicationRecord
  TRACKING_MODES = %w[counted order_only].freeze

  belongs_to :order_guide
  belongs_to :inventory_item
  belongs_to :order_guide_section, optional: true
  belongs_to :preferred_supplier, class_name: "Supplier", optional: true

  has_many :inventory_count_lines, dependent: :nullify

  validates :order_guide_id, uniqueness: { scope: :inventory_item_id }
  validates :position, numericality: { only_integer: true }
  validates :tracking_mode, inclusion: { in: TRACKING_MODES }

  scope :active, -> { where(active: true) }
  scope :primary_guide, -> { where(primary_guide: true) }
  scope :counted, -> { where(tracking_mode: "counted") }
  scope :order_only, -> { where(tracking_mode: "order_only") }
  scope :ordered, -> { joins(:order_guide).order("order_guides.position ASC", :position, "order_guides.name ASC") }

  before_save :clear_other_primary_memberships, if: :active_primary_guide?

  def active_primary_guide?
    active? && primary_guide?
  end

  def counted?
    tracking_mode == "counted"
  end

  def order_only?
    tracking_mode == "order_only"
  end

  def setup_needed?
    counted? && (expected_usage_quantity.blank? || buffer_quantity.blank?)
  end

  def target_after_order
    return nil if setup_needed? || order_only?

    expected_usage_quantity.to_d + buffer_quantity.to_d
  end

  def latest_count_line
    inventory_count_lines
      .joins(:inventory_count)
      .order("inventory_counts.counted_at DESC", "inventory_count_lines.id DESC")
      .first
  end

  def deactivate!
    update!(active: false, primary_guide: false)
  end

  private

  def clear_other_primary_memberships
    inventory_item.order_guide_memberships
      .active
      .primary_guide
      .where.not(id: id)
      .update_all(primary_guide: false, updated_at: Time.current)
  end
end
