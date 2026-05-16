class InventorySection < ApplicationRecord
  has_many :inventory_items, dependent: :nullify
  has_many :inventory_counts, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:position, :name) }
end
