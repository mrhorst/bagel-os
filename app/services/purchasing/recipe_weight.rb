module Purchasing
  # Rolls a recipe's ingredient lines up into a total weight, in grams, without
  # guessing. A line is weighed when its amount is given in a weight unit, or in
  # a count unit for a product that records an average weight per unit (the
  # count↔weight bridge). Volumes are deliberately not weighed — that needs a
  # per-ingredient density we don't keep — so they stay uncertain. Like costing,
  # the total is shown only when every line is weighed; otherwise a clearly
  # labelled partial is offered.
  class RecipeWeight
    BASE_UNIT = Measurement::Units::BASE_UNITS[Measurement::Units::WEIGHT] # "g"

    Line = Struct.new(:ingredient, :grams, :status, :reason, keyword_init: true) do
      def weighed?
        status == :weighed
      end
    end

    def initialize(recipe)
      @recipe = recipe
    end

    def lines
      @lines ||= @recipe.recipe_ingredients.ordered.map { |ingredient| weight_line(ingredient) }
    end

    def weight_for(ingredient)
      lines_by_ingredient_id[ingredient.id]
    end

    def weighed_lines
      lines.select(&:weighed?)
    end

    def total_lines
      lines.size
    end

    # Grams we could account for — shown even when the estimate is incomplete.
    def subtotal_grams
      weighed_lines.sum(&:grams)
    end

    def complete?
      lines.any? && lines.all?(&:weighed?)
    end

    def total_grams
      complete? ? subtotal_grams : nil
    end

    # Grams per serving, only when the whole recipe is weighed and a positive
    # yield is recorded.
    def weight_per_serving_grams
      return unless complete? && @recipe.yield_described?

      (total_grams / @recipe.yield_quantity).round(2)
    end

    private

    def lines_by_ingredient_id
      @lines_by_ingredient_id ||= lines.index_by { |line| line.ingredient.id }
    end

    def weight_line(ingredient)
      return uncertain(ingredient, "No amount entered for this line") if ingredient.quantity.blank?
      return uncertain(ingredient, "No unit entered for this line") if ingredient.unit.blank?

      grams = grams_for(ingredient)
      return uncertain(ingredient, weight_reason(ingredient)) if grams.nil?

      Line.new(ingredient: ingredient, grams: grams.round(2), status: :weighed, reason: nil)
    end

    # Grams for a line, or nil when we can't weigh it without guessing. A weight
    # unit converts directly; a count unit converts only when the linked product
    # records an average weight per unit.
    def grams_for(ingredient)
      case Measurement::Units.dimension(ingredient.unit)
      when Measurement::Units::WEIGHT
        Measurement::Units.to_base(ingredient.quantity, ingredient.unit)
      when Measurement::Units::COUNT
        grams_per_each = ingredient.inventory_item&.product&.each_weight_in_grams
        return if grams_per_each.blank? || grams_per_each.zero?

        eaches = Measurement::Units.convert(ingredient.quantity, from: ingredient.unit, to: "each")
        eaches * grams_per_each
      end
    end

    def weight_reason(ingredient)
      case Measurement::Units.dimension(ingredient.unit)
      when nil
        %(Unit "#{ingredient.unit}" isn't one we can weigh — left uncertain rather than guessed)
      when Measurement::Units::VOLUME
        %(A volume like "#{ingredient.unit}" can't be weighed without a density, so it's left out of the total)
      when Measurement::Units::COUNT
        name = ingredient.inventory_item&.product&.canonical_name || ingredient.display_name
        %(#{name} is counted; set an average weight per unit on the product to include it in the weight total)
      end
    end

    def uncertain(ingredient, reason)
      Line.new(ingredient: ingredient, grams: nil, status: :uncertain, reason: reason)
    end
  end
end
