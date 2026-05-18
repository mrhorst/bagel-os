class InventoryCountLine < ApplicationRecord
  belongs_to :inventory_count
  belongs_to :inventory_item
  belongs_to :order_guide_membership, optional: true

  validates :quantity_on_hand, numericality: { greater_than_or_equal_to: 0 }
end
