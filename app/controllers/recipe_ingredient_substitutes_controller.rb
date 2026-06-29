class RecipeIngredientSubstitutesController < ApplicationController
  include RecipeShowData

  require_module_access :recipes

  def create
    @recipe = Recipe.find(params[:recipe_id])
    @ingredient = @recipe.recipe_ingredients.find(params[:ingredient_id])
    @new_substitute = @ingredient.substitutes.build(substitute_params)
    @new_substitute.position ||= next_position

    if @new_substitute.save
      redirect_to recipe_path(@recipe), notice: "Substitute added."
    else
      # Re-render the recipe in place so the rejected substitute keeps its input
      # and shows the error, instead of redirecting and dropping it.
      @substitute_errors_for = @ingredient.id
      load_recipe_show_data
      render "recipes/show", status: :unprocessable_entity
    end
  end

  def destroy
    substitute = RecipeIngredientSubstitute.find(params[:id])
    recipe = substitute.recipe_ingredient.recipe
    substitute.destroy
    redirect_to recipe_path(recipe), notice: "Substitute removed."
  end

  private

  def substitute_params
    params.require(:recipe_ingredient_substitute).permit(:inventory_item_id, :name, :quantity, :unit, :note)
  end

  def next_position
    @ingredient.substitutes.maximum(:position).to_i + 1
  end
end
