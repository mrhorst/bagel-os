class ProductCategory < ApplicationRecord
  has_many :products, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:sort_order, :name) }

  def self.unknown
    find_or_create_by!(name: "Other / unknown") do |category|
      category.sort_order = 999
      category.description = "Fallback category for products that need human classification."
    end
  end
end
