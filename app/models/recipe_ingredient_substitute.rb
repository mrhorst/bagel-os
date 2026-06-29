class RecipeIngredientSubstitute < ApplicationRecord
  # An alternative that can stand in for a recipe line — "if you're out of X, use
  # Y". It mirrors a recipe line: it prefers a linked inventory item but can be a
  # free-text name, and it may carry its own amount when the swap isn't 1:1. When
  # its amount is left blank, the line's own amount applies.
  belongs_to :recipe_ingredient
  belongs_to :inventory_item, optional: true

  validates :name, presence: true, unless: -> { inventory_item_id.present? }
  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true

  scope :ordered, -> { order(:position, :id) }

  def display_name
    inventory_item&.name.presence || name
  end

  # The amount to use for this substitute: its own when given, otherwise the
  # parent line's. Either part may be blank when it isn't known — never guessed.
  def effective_quantity
    quantity.presence || recipe_ingredient&.quantity
  end

  def effective_unit
    unit.presence || recipe_ingredient&.unit
  end
end
