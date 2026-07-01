class RecipeModifierGroupsController < ApplicationController
  require_module_access :recipes

  before_action :set_recipe

  def create
    attachment = @recipe.recipe_modifier_groups.build(attachment_params)
    attachment.position ||= next_position

    if attachment.save
      # Land back on the modifiers panel, not the top of the page — the same
      # place-preserving pattern as ingredient adds.
      redirect_to recipe_path(@recipe, anchor: "modifiers"), notice: "Modifier attached."
    else
      # The attach form is a single select (offering only unattached groups),
      # so a rejected save means nothing was chosen — a flash covers it without
      # threading form state through the show render like the richer forms do.
      redirect_to recipe_path(@recipe, anchor: "modifiers"),
                  alert: "Choose a modifier to attach."
    end
  end

  def destroy
    attachment = @recipe.recipe_modifier_groups.find(params[:id])
    attachment.destroy
    # Detaching only unlinks this recipe — the shared group and its options
    # stay in the library untouched.
    redirect_to recipe_path(@recipe, anchor: "modifiers"), notice: "Modifier detached."
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:recipe_id])
  end

  def attachment_params
    params.require(:recipe_modifier_group).permit(:modifier_group_id)
  end

  def next_position
    @recipe.recipe_modifier_groups.maximum(:position).to_i + 1
  end
end
