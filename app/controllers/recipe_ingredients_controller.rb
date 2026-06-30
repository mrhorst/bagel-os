class RecipeIngredientsController < ApplicationController
  require_module_access :recipes

  before_action :set_recipe

  def create
    @new_ingredient = @recipe.recipe_ingredients.build(ingredient_params)
    @new_ingredient.position ||= next_position

    if @new_ingredient.save
      # Land back on the "Add ingredient" form (bottom of the show page) rather
      # than the top, so building a recipe line-by-line doesn't make the user
      # scroll past the whole ingredient table after every add. The form submits
      # natively (data-turbo=false) so the browser honors this fragment — see
      # the note in app/views/recipes/_ingredient_form.html.erb.
      redirect_to recipe_path(@recipe, anchor: "add-ingredient"), notice: "Ingredient added."
    else
      # Re-render the recipe in place so the rejected line keeps what was typed
      # and shows the error, instead of redirecting and dropping the input.
      render_recipe_with_errors
    end
  end

  def update
    @ingredient = @recipe.recipe_ingredients.find(params[:id])

    if @ingredient.update(ingredient_params)
      # Return to the row that was just edited, not the top of the page.
      redirect_to recipe_path(@recipe, anchor: "ingredient-line-#{@ingredient.id}"), notice: "Ingredient updated."
    else
      @editing_ingredient = @ingredient
      render_recipe_with_errors
    end
  end

  def destroy
    ingredient = @recipe.recipe_ingredients.find(params[:id])
    ingredient.destroy
    # Remove stays a Turbo submit so its turbo_confirm guard fires, and Turbo
    # drops a redirect fragment — so no place-preserving anchor here (the row is
    # gone anyway). Add/edit use native submits (data-turbo=false) precisely so
    # their fragment lands; remove keeps the confirmation instead.
    redirect_to recipe_path(@recipe), notice: "Ingredient removed."
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:recipe_id])
  end

  def render_recipe_with_errors
    @ingredients = @recipe.recipe_ingredients.ordered.includes(inventory_item: { product: :price_observations })
    @new_ingredient ||= @recipe.recipe_ingredients.build
    @inventory_items = InventoryItem.active.ordered
    @costing = Purchasing::RecipeCosting.new(@recipe)
    render "recipes/show", status: :unprocessable_entity
  end

  def ingredient_params
    params.require(:recipe_ingredient).permit(:inventory_item_id, :name, :quantity, :unit)
  end

  def next_position
    @recipe.recipe_ingredients.maximum(:position).to_i + 1
  end
end
