class RecipeIngredientsController < ApplicationController
  require_module_access :recipes

  before_action :set_recipe

  def create
    @new_ingredient = @recipe.recipe_ingredients.build(ingredient_params)
    @new_ingredient.position ||= next_position

    if @new_ingredient.save
      redirect_to recipe_path(@recipe), notice: "Ingredient added."
    else
      # Re-render the recipe in place so the rejected line keeps what was typed
      # and shows the error, instead of redirecting and dropping the input.
      render_recipe_with_errors
    end
  end

  def update
    @ingredient = @recipe.recipe_ingredients.find(params[:id])

    if @ingredient.update(ingredient_params)
      redirect_to recipe_path(@recipe), notice: "Ingredient updated."
    else
      @editing_ingredient = @ingredient
      render_recipe_with_errors
    end
  end

  def destroy
    ingredient = @recipe.recipe_ingredients.find(params[:id])
    ingredient.destroy
    redirect_to recipe_path(@recipe), notice: "Ingredient removed."
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:recipe_id])
  end

  def render_recipe_with_errors
    @ingredients = @recipe.recipe_ingredients.ordered.includes(:inventory_item)
    @new_ingredient ||= @recipe.recipe_ingredients.build
    @inventory_items = InventoryItem.active.ordered
    render "recipes/show", status: :unprocessable_entity
  end

  def ingredient_params
    params.require(:recipe_ingredient).permit(:inventory_item_id, :name, :quantity, :unit)
  end

  def next_position
    @recipe.recipe_ingredients.maximum(:position).to_i + 1
  end
end
