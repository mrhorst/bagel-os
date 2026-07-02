module Purchasing
  # Estimates how the guest choices attached to a recipe move its cost. Only
  # ingredient-kind modifier groups participate — preparation choices (how an
  # egg is cooked) never touch inventory or cost. Each option costs through
  # LineCosting under the same never-guess rules as a recipe line.
  #
  # Per group, three figures:
  #   standard — the default option, taken min_select times ("pick 2" counts
  #              the default twice). This is the configuration a guest gets
  #              when they don't say otherwise.
  #   min/max  — the cheapest option × min_select and the priciest option ×
  #              max_select. The bounds assume any option can be repeated
  #              across picks; they're a range, not a menu simulation.
  #
  # A group with any uncostable option reports uncertain with that option's
  # reason — a range built from half the options wouldn't be a bound at all.
  class ModifierCosting
    GroupCost = Struct.new(:group, :option_lines, :standard_cost, :min_cost, :max_cost, :status, :reason, keyword_init: true) do
      def costed?
        status == :costed
      end
    end

    def initialize(recipe, base: nil, price_profile: ProductPriceProfile.new)
      @recipe = recipe
      # The base ingredient costing, so combined "recipe + standard choices"
      # totals don't recost every line. Built here when not handed in.
      @base = base || RecipeCosting.new(recipe, price_profile: price_profile)
      @line_costing = LineCosting.new(price_profile: price_profile)
    end

    def groups
      @groups ||= ingredient_groups.map { |group| group_cost(group) }
    end

    def costed_groups
      groups.select(&:costed?)
    end

    def complete?
      groups.any? && groups.all?(&:costed?)
    end

    # Whether the whole item — base lines plus every choice — can be costed. A
    # recipe with no fixed lines (an all-choices item like an eggle) counts:
    # its base contributes zero, not uncertainty.
    def item_complete?
      groups.any? && complete? && (@base.complete? || @base.total_lines.zero?)
    end

    # The cost of the item as ordered with no special requests: the base recipe
    # plus each group's default pick. Nil unless everything is costed.
    def standard_total
      return unless item_complete?

      base_amount + groups.sum(&:standard_cost)
    end

    # The bounds across all choices — cheapest picks to priciest picks.
    def min_total
      return unless item_complete?

      base_amount + groups.sum(&:min_cost)
    end

    def max_total
      return unless item_complete?

      base_amount + groups.sum(&:max_cost)
    end

    private

    def base_amount
      @base.total_lines.zero? ? 0 : @base.total
    end

    def ingredient_groups
      @recipe.recipe_modifier_groups.ordered.includes(modifier_group: { modifier_options: { inventory_item: :product } })
             .map(&:modifier_group).select(&:ingredient?)
    end

    def group_cost(group)
      options = group.modifier_options
      return uncertain(group, [], "No options yet") if options.empty?

      option_lines = options.index_with { |option| @line_costing.cost(option) }
      failed = option_lines.reject { |_option, line| line.costed? }
      if failed.any?
        option, line = failed.first
        return uncertain(group, option_lines, "#{option.display_name}: #{line.reason}")
      end

      costs = option_lines.values.map(&:cost)
      default_cost = option_lines.fetch(group.default_option).cost

      GroupCost.new(
        group: group,
        option_lines: option_lines,
        standard_cost: default_cost * group.min_select,
        min_cost: costs.min * group.min_select,
        max_cost: costs.max * group.max_select,
        status: :costed,
        reason: nil
      )
    end

    def uncertain(group, option_lines, reason)
      GroupCost.new(group: group, option_lines: option_lines, standard_cost: nil, min_cost: nil, max_cost: nil,
                    status: :uncertain, reason: reason)
    end
  end
end
