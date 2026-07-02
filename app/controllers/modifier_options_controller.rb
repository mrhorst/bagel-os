class ModifierOptionsController < ApplicationController
  include ModifierGroupShowData

  require_module_access :recipes

  before_action :set_modifier_group

  def create
    @new_option = @modifier_group.modifier_options.build(option_params)
    @new_option.position ||= next_position

    if @new_option.save
      # Land back on the "Add option" form (bottom of the show page) so a group
      # can be built option-by-option without scrolling past the table after
      # every add — the same place-preserving pattern as recipe ingredients.
      redirect_to modifier_group_path(@modifier_group, anchor: "add-option"), notice: "Option added."
    else
      # Re-render the group in place so the rejected option keeps what was
      # typed and shows the error, instead of redirecting and dropping input.
      render_group_with_errors
    end
  end

  def update
    @option = @modifier_group.modifier_options.find(params[:id])

    if @option.update(option_params)
      # Return to the row that was just edited, not the top of the page.
      redirect_to modifier_group_path(@modifier_group, anchor: "option-line-#{@option.id}"), notice: "Option updated."
    else
      @editing_option = @option
      render_group_with_errors
    end
  end

  def destroy
    option = @modifier_group.modifier_options.find(params[:id])
    option.destroy
    # Remove stays a Turbo submit so its turbo_confirm guard fires; no anchor
    # needed since the row is gone (same trade-off as recipe ingredients).
    redirect_to modifier_group_path(@modifier_group), notice: "Option removed."
  end

  private

  def set_modifier_group
    @modifier_group = ModifierGroup.find(params[:modifier_group_id])
  end

  def render_group_with_errors
    load_modifier_group_show_data
    render "modifier_groups/show", status: :unprocessable_entity
  end

  def option_params
    params.require(:modifier_option).permit(:inventory_item_id, :name, :quantity, :unit, :default_choice)
  end

  def next_position
    @modifier_group.modifier_options.maximum(:position).to_i + 1
  end
end
