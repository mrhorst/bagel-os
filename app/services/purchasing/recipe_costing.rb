module Purchasing
  # Estimates the cost of a recipe from existing price data, without ever
  # inventing a number. A line is costed only when it links to an inventory item
  # whose product has a recorded comparable (standard) unit price AND the recipe
  # line's unit matches that priced unit — we never convert between units we
  # can't relate. Anything missing leaves the line "uncertain" with a plain
  # reason, and the recipe total is shown only when every line is costed.
  class RecipeCosting
    Line = Struct.new(:ingredient, :unit_price, :priced_unit, :cost, :status, :reason, keyword_init: true) do
      def costed?
        status == :costed
      end
    end

    def initialize(recipe, price_profile: ProductPriceProfile.new)
      @recipe = recipe
      @price_profile = price_profile
    end

    def lines
      @lines ||= @recipe.recipe_ingredients.ordered.map { |ingredient| cost_line(ingredient) }
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

    private

    def lines_by_ingredient_id
      @lines_by_ingredient_id ||= lines.index_by { |line| line.ingredient.id }
    end

    def cost_line(ingredient)
      item = ingredient.inventory_item
      return uncertain(ingredient, "Not linked to an inventory item") unless item

      product = item.product
      return uncertain(ingredient, "Inventory item isn't linked to a product") unless product

      observation = latest_priced_observation(product)
      unit_price = observation&.standard_unit_price
      priced_unit = observation&.standard_unit
      return uncertain(ingredient, "No comparable price recorded for #{product.canonical_name} yet") if unit_price.blank? || priced_unit.blank?

      return uncertain(ingredient, "No amount entered for this line") if ingredient.quantity.blank?
      return uncertain(ingredient, "No unit entered for this line") if ingredient.unit.blank?

      unless units_match?(ingredient.unit, priced_unit)
        return uncertain(
          ingredient,
          %(Recipe unit "#{ingredient.unit}" doesn't match the priced unit "#{priced_unit}" — no conversion is assumed)
        )
      end

      Line.new(
        ingredient: ingredient,
        unit_price: unit_price,
        priced_unit: priced_unit,
        cost: (ingredient.quantity * unit_price).round(2),
        status: :costed,
        reason: nil
      )
    end

    def uncertain(ingredient, reason)
      Line.new(ingredient: ingredient, unit_price: nil, priced_unit: nil, cost: nil, status: :uncertain, reason: reason)
    end

    def latest_priced_observation(product)
      product.price_observations.with_standard_unit_price.order(observed_at: :desc, id: :desc).first
    end

    # Match units conservatively: case/whitespace-insensitive, and tolerant of a
    # trailing plural "s" (lb/lbs, cup/cups). This is NOT a unit conversion — it
    # only treats obviously-the-same labels as equal; genuinely different units
    # (cup vs lb) never match, so they fall through to "uncertain".
    def units_match?(recipe_unit, priced_unit)
      normalize_unit(recipe_unit) == normalize_unit(priced_unit)
    end

    def normalize_unit(unit)
      unit.to_s.strip.downcase.chomp("s")
    end
  end
end
