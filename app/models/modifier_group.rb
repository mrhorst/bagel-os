class ModifierGroup < ApplicationRecord
  # A reusable choice a guest makes on an item — "Meat", "Cheese", "Bread",
  # "Egg style", "Sides". Defined once and attached to any number of recipes, so
  # the same "Sides" choice is shared across every platter rather than retyped.
  #
  # A group is either an "ingredient" choice (its options link to inventory items
  # and roll into cost/weight) or a "preparation" choice (prep-only, like how an
  # egg is cooked — no inventory, no cost).
  enum :kind, { ingredient: "ingredient", preparation: "preparation" }, default: "ingredient"

  has_many :modifier_options, -> { ordered }, dependent: :destroy, inverse_of: :modifier_group
  has_many :recipe_modifier_groups, dependent: :destroy
  has_many :recipes, through: :recipe_modifier_groups

  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: false }, if: -> { name.present? }
  # How many options a guest picks. Both must be positive, and the max can't ask
  # for fewer than the min.
  validates :min_select, numericality: { only_integer: true, greater_than: 0 }
  validates :max_select, numericality: { only_integer: true, greater_than_or_equal_to: :min_select },
                         if: -> { min_select.present? }

  scope :ordered, -> { order(:position, :name) }

  # The standard pick for this group (over medium, bagel), used for the "standard
  # configuration" cost. Falls back to the first option so a group without an
  # explicit default still resolves to something predictable.
  def default_option
    modifier_options.detect(&:default_choice?) || modifier_options.first
  end

  # A short "pick 1" / "pick 2" / "pick 1–2" summary of the selection rule.
  def selection_summary
    return "pick #{min_select}" if min_select == max_select

    "pick #{min_select}–#{max_select}"
  end
end
