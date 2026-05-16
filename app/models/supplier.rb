class Supplier < ApplicationRecord
  has_many :import_batches, dependent: :restrict_with_error
  has_many :receipts, dependent: :restrict_with_error
  has_many :receipt_line_items, dependent: :restrict_with_error
  has_many :products, dependent: :restrict_with_error
  has_many :price_observations, dependent: :restrict_with_error
  has_many :supplier_product_packs, dependent: :restrict_with_error
  has_many :preferred_inventory_items, class_name: "InventoryItem", foreign_key: :preferred_supplier_id, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  def self.primary
    find_or_create_by!(name: "Primary Supplier") do |supplier|
      supplier.notes = "Default supplier used for local development and sanitized fixtures. Private installs can rename or replace this supplier."
    end
  end
end
