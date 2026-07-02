class ModifierGroupsController < ApplicationController
  include ModifierGroupShowData

  # The modifier library is part of the recipes area, so it shares that
  # module's access rule rather than introducing a new permission.
  require_module_access :recipes

  before_action :set_modifier_group, only: %i[show edit update destroy]

  def index
    @modifier_groups = ModifierGroup.ordered.includes(:modifier_options, :recipes)
  end

  def show
    load_modifier_group_show_data
  end

  def new
    @modifier_group = ModifierGroup.new(position: next_position)
  end

  def create
    @modifier_group = ModifierGroup.new(modifier_group_params)

    if @modifier_group.save
      redirect_to @modifier_group, notice: "Modifier created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @modifier_group.update(modifier_group_params)
      redirect_to @modifier_group, notice: "Modifier updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @modifier_group.destroy
    redirect_to modifier_groups_path, notice: "Modifier deleted."
  end

  private

  def set_modifier_group
    @modifier_group = ModifierGroup.find(params[:id])
  end

  def modifier_group_params
    params.require(:modifier_group).permit(:name, :kind, :min_select, :max_select, :position)
  end

  def next_position
    (ModifierGroup.maximum(:position) || 0) + 1
  end
end
