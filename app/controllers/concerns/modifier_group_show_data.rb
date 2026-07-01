module ModifierGroupShowData
  extend ActiveSupport::Concern

  private

  # The instance data the modifier_groups/show template needs. Shared by
  # ModifierGroupsController (the normal render) and ModifierOptionsController
  # (which re-renders show in place when a nested option form is rejected) so
  # the two can't drift — the same guard RecipeShowData provides for recipes.
  def load_modifier_group_show_data
    @options = @modifier_group.modifier_options.ordered.includes(:inventory_item)
    @new_option ||= @modifier_group.modifier_options.build
    @inventory_items = InventoryItem.active.ordered
  end
end
