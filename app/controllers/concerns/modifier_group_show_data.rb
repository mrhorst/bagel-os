module ModifierGroupShowData
  extend ActiveSupport::Concern

  private

  # The instance data the modifier_groups/show template needs. Shared by
  # ModifierGroupsController (the normal render) and ModifierOptionsController
  # (which re-renders show in place when a nested option form is rejected) so
  # the two can't drift — the same guard RecipeShowData provides for recipes.
  def load_modifier_group_show_data
    @options = @modifier_group.modifier_options.ordered.includes(inventory_item: { product: :price_observations })
    @new_option ||= @modifier_group.modifier_options.build
    @inventory_items = InventoryItem.active.ordered
    # Per-option cost estimates, shown only for ingredient choices — a
    # preparation choice never costs anything.
    line_costing = Purchasing::LineCosting.new
    @option_costs = @modifier_group.ingredient? ? @options.index_with { |option| line_costing.cost(option) } : {}
  end
end
