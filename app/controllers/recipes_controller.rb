class RecipesController < ApplicationController
  include RecipeShowData

  require_module_access :recipes

  before_action :set_recipe, only: %i[show edit update]

  def index
    @recipes = Recipe.ordered
  end

  def show
    load_recipe_show_data
  end

  def new
    @recipe = Recipe.new(active: true, position: next_position)
  end

  def create
    @recipe = Recipe.new(recipe_params)

    if @recipe.save
      redirect_to @recipe, notice: "Recipe created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @recipe.update(recipe_params)
      redirect_to @recipe, notice: "Recipe updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end

  def recipe_params
    params.require(:recipe).permit(:name, :description, :active, :position, :yield_quantity, :yield_unit)
  end

  def next_position
    (Recipe.maximum(:position) || 0) + 1
  end
end
