class OrderGuideItem < ApplicationRecord
  belongs_to :order_guide_import
  belongs_to :inventory_item, optional: true

  validates :guide_type, :section_name, :item_name, :raw_line, presence: true

  scope :active, -> { where(active: true) }
  scope :needs_review, -> { where(needs_review: true) }
  scope :ordered, -> { order(:guide_type, :section_name, :position, :item_name) }

  def linked_product
    inventory_item&.product
  end
end
