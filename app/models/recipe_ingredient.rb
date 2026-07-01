class RecipeIngredient < ApplicationRecord
  # One line of a recipe. It preferably references an existing InventoryItem (so
  # it stays traceable to the purchasing/inventory model and, later, to pricing),
  # but it can also be a free-text name for something not tracked in inventory.
  belongs_to :recipe
  belongs_to :inventory_item, optional: true
  has_many :substitutes, class_name: "RecipeIngredientSubstitute", dependent: :destroy

  # A line needs *something* to identify it: either a linked inventory item or a
  # typed name.
  validates :name, presence: true, unless: -> { inventory_item_id.present? }
  # Amount is optional — we don't force a number we don't have — but when given
  # it must be a real positive quantity. The unit stays free text and uncertain
  # units are left blank rather than guessed.
  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true

  scope :ordered, -> { order(:position, :id) }

  # What to show for this line: the linked inventory item's name when present,
  # otherwise the free-text name.
  def display_name
    inventory_item&.name.presence || name
  end
end
