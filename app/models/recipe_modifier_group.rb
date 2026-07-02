class RecipeModifierGroup < ApplicationRecord
  # Attaches a reusable modifier group to a recipe. The eggle attaches "Egg
  # style", "Meat", "Cheese" and "Bread"; a platter also attaches "Sides". The
  # same group can be attached to many recipes; position orders the groups
  # within one recipe.
  belongs_to :recipe
  belongs_to :modifier_group

  # A group is attached to a recipe at most once.
  validates :modifier_group_id, uniqueness: { scope: :recipe_id }

  scope :ordered, -> { order(:position, :id) }
end
