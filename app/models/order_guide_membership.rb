class OrderGuideMembership < ApplicationRecord
  belongs_to :order_guide
  belongs_to :inventory_item
  belongs_to :preferred_supplier, class_name: "Supplier", optional: true

  validates :order_guide_id, uniqueness: { scope: :inventory_item_id }
  validates :position, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :primary_guide, -> { where(primary_guide: true) }
  scope :ordered, -> { joins(:order_guide).order("order_guides.position ASC", :position, "order_guides.name ASC") }

  before_save :clear_other_primary_memberships, if: :active_primary_guide?

  def active_primary_guide?
    active? && primary_guide?
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
