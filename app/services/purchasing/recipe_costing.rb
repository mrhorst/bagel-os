module Purchasing
  # Estimates the cost of a recipe from existing price data, without ever
  # inventing a number. A line is costed only when it links to an inventory item
  # whose product has a recorded comparable (standard) unit price AND the recipe
  # line's amount can be converted into that priced unit. Conversion stays inside
  # a dimension (weight/volume/count); the one cross-dimension bridge we allow is
  # count↔weight, and only when the product records an average weight per unit.
  # Anything we can't convert leaves the line "uncertain" with a plain reason,
  # and the recipe total is shown only when every line is costed.
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

    # Cost per serving, only when the whole recipe is costed and a positive yield
    # is recorded — never divide a partial total.
    def cost_per_serving
      return unless complete? && @recipe.yield_described?

      (total / @recipe.yield_quantity).round(2)
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

      priced_quantity = quantity_in_priced_unit(ingredient, product, priced_unit)
      if priced_quantity.nil?
        return uncertain(ingredient, conversion_reason(ingredient.unit, priced_unit, product))
      end

      Line.new(
        ingredient: ingredient,
        unit_price: unit_price,
        priced_unit: priced_unit,
        cost: (priced_quantity * unit_price).round(2),
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

    # The recipe line's amount expressed in the product's priced unit, or nil
    # when we can't convert it without guessing. A plain in-dimension conversion
    # is tried first; failing that, the only cross-dimension move allowed is
    # count↔weight, and only when the product supplies an average weight per
    # unit to bridge the two.
    def quantity_in_priced_unit(ingredient, product, priced_unit)
      quantity = ingredient.quantity
      recipe_unit = ingredient.unit

      direct = Measurement::Units.convert(quantity, from: recipe_unit, to: priced_unit)
      return direct if direct

      grams_per_each = product.each_weight_in_grams
      return if grams_per_each.blank? || grams_per_each.zero?

      recipe_dimension = Measurement::Units.dimension(recipe_unit)
      priced_dimension = Measurement::Units.dimension(priced_unit)

      if recipe_dimension == Measurement::Units::COUNT && priced_dimension == Measurement::Units::WEIGHT
        eaches = Measurement::Units.convert(quantity, from: recipe_unit, to: "each")
        grams = eaches * grams_per_each
        Measurement::Units.convert(grams, from: "g", to: priced_unit)
      elsif recipe_dimension == Measurement::Units::WEIGHT && priced_dimension == Measurement::Units::COUNT
        grams = Measurement::Units.to_base(quantity, recipe_unit)
        eaches = grams / grams_per_each
        Measurement::Units.convert(eaches, from: "each", to: priced_unit)
      end
    end

    # A plain-language reason a line couldn't be converted, tailored so the fix
    # is obvious: an unrecognised unit, a count↔weight gap that an average weight
    # would close, or genuinely incompatible dimensions.
    def conversion_reason(recipe_unit, priced_unit, product)
      recipe_dimension = Measurement::Units.dimension(recipe_unit)
      priced_dimension = Measurement::Units.dimension(priced_unit)

      if recipe_dimension.nil?
        %(Recipe unit "#{recipe_unit}" isn't one we can convert — left uncertain rather than guessed)
      elsif priced_dimension.nil?
        %(The priced unit "#{priced_unit}" isn't one we can convert — left uncertain rather than guessed)
      elsif count_and_weight?(recipe_dimension, priced_dimension)
        %(#{product.canonical_name} is priced by #{priced_unit} but the recipe uses #{recipe_unit}; set an average weight per unit on the product to bridge count and weight)
      else
        %(Recipe unit "#{recipe_unit}" and the priced unit "#{priced_unit}" measure different things, so no conversion is assumed)
      end
    end

    def count_and_weight?(first_dimension, second_dimension)
      [first_dimension, second_dimension].sort == [Measurement::Units::COUNT, Measurement::Units::WEIGHT].sort
    end
  end
end
