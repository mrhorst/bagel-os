module Purchasing
  # Estimates the cost of a recipe from existing price data, without ever
  # inventing a number. Each ingredient line costs through LineCosting (see the
  # rules there); anything that can't be converted stays "uncertain" with a
  # plain reason, and the recipe total is shown only when every line is costed.
  class RecipeCosting
    Line = LineCosting::Line

    def initialize(recipe, price_profile: ProductPriceProfile.new)
      @recipe = recipe
      @line_costing = LineCosting.new(price_profile: price_profile)
    end

    def lines
      @lines ||= @recipe.recipe_ingredients.ordered.map { |ingredient| @line_costing.cost(ingredient) }
    end

    def cost_for(ingredient)
      lines_by_ingredient_id[ingredient.id]
    end

    def costed_lines
      lines.select(&:costed?)
    end

    def total_lines
      lines.size
    end

    # The sum of the lines we could cost — shown even when the estimate is
    # incomplete, clearly labelled as a partial.
    def subtotal
      costed_lines.sum(&:cost)
    end

    # A complete total exists only when there is at least one line and every
    # line is costed.
    def complete?
      lines.any? && lines.all?(&:costed?)
    end

    def total
      complete? ? subtotal : nil
    end

    # Cost per serving, only when the whole recipe is costed and a positive yield
    # is recorded — never divide a partial total.
    def cost_per_serving
      return unless complete? && @recipe.yield_described?

      (total / @recipe.yield_quantity).round(2)
    end

    private

    def lines_by_ingredient_id
      @lines_by_ingredient_id ||= lines.index_by { |line| line.source.id }
    end
  end
end
