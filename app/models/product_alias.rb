class ProductAlias < ApplicationRecord
  belongs_to :product

  validates :raw_name, presence: true
  validates :raw_name, uniqueness: { scope: [ :product_id, :raw_sku ] }

  scope :approved, -> { where(approved: true) }
end
