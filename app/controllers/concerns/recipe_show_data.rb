module RecipeShowData
  extend ActiveSupport::Concern

  private

  # The instance data the recipes/show template needs. Shared by RecipesController
  # (the normal render) and the ingredient/substitute controllers (which
  # re-render show in place when a nested form is rejected) so the two can't
  # drift — a missing here once meant a rejected ingredient crashed the page.
  def load_recipe_show_data
    @ingredients = @recipe.recipe_ingredients.ordered.includes(
      substitutes: { inventory_item: :product },
      inventory_item: { product: :price_observations }
    )
    @new_ingredient ||= @recipe.recipe_ingredients.build
    @inventory_items = InventoryItem.active.ordered
    # The guest choices attached to this recipe, and the library groups still
    # available to attach.
    @modifier_attachments = @recipe.recipe_modifier_groups.includes(modifier_group: { modifier_options: :inventory_item })
    @attachable_modifier_groups = ModifierGroup.ordered.where.not(id: @modifier_attachments.map(&:modifier_group_id))
    @costing = Purchasing::RecipeCosting.new(@recipe)
    @weight = Purchasing::RecipeWeight.new(@recipe)
    @modifier_costing = Purchasing::ModifierCosting.new(@recipe, base: @costing)
  end
end
