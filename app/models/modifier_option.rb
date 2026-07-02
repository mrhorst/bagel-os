class ModifierOption < ApplicationRecord
  # One choice within a modifier group — "bacon", "swiss", "rye", "over medium".
  # It mirrors a recipe line: it prefers a linked inventory item (so an
  # ingredient choice stays traceable to purchasing and pricing) but can be a
  # free-text name for a prep-only choice or something not tracked in inventory.
  belongs_to :modifier_group, inverse_of: :modifier_options

  belongs_to :inventory_item, optional: true

  # Like a recipe line, an option needs *something* to identify it: a linked
  # inventory item or a typed name.
  validates :name, presence: true, unless: -> { inventory_item_id.present? }
  # Amount is optional — we don't force a number we don't have — but when given
  # it must be a real positive quantity. The unit stays free text; uncertain
  # units are left blank rather than guessed.
  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true

  scope :ordered, -> { order(:position, :id) }

  # What to show for this option: the linked inventory item's name when present,
  # otherwise the free-text name.
  def display_name
    inventory_item&.name.presence || name
  end
end
