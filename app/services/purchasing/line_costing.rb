module Purchasing
  # Costs one "amount of an item" line from existing price data, without ever
  # inventing a number. Recipe ingredient lines and modifier options share the
  # same shape (inventory_item, quantity, unit), so both cost through here. A
  # line is costed only when it links to an inventory item whose product has a
  # recorded comparable (standard) unit price AND the line's amount can be
  # converted into that priced unit. Conversion stays inside a dimension
  # (weight/volume/count); the one cross-dimension bridge we allow is
  # count↔weight, and only when the product records an average weight per unit.
  # Anything we can't convert leaves the line "uncertain" with a plain reason.
  class LineCosting
    Line = Struct.new(:source, :unit_price, :priced_unit, :cost, :status, :reason, keyword_init: true) do
      def costed?
        status == :costed
      end
    end

    def initialize(price_profile: ProductPriceProfile.new)
      @price_profile = price_profile
    end

    def cost(source)
      item = source.inventory_item
      return uncertain(source, "Not linked to an inventory item") unless item

      product = item.product
      return uncertain(source, "Inventory item isn't linked to a product") unless product

      observation = latest_priced_observation(product)
      unit_price = observation&.standard_unit_price
      priced_unit = observation&.standard_unit
      return uncertain(source, "No comparable price recorded for #{product.canonical_name} yet") if unit_price.blank? || priced_unit.blank?

      return uncertain(source, "No amount entered for this line") if source.quantity.blank?
      return uncertain(source, "No unit entered for this line") if source.unit.blank?

      priced_quantity = quantity_in_priced_unit(source, product, priced_unit)
      if priced_quantity.nil?
        return uncertain(source, conversion_reason(source.unit, priced_unit, product))
      end

      Line.new(
        source: source,
        unit_price: unit_price,
        priced_unit: priced_unit,
        cost: (priced_quantity * unit_price).round(2),
        status: :costed,
        reason: nil
      )
    end

    private

    def uncertain(source, reason)
      Line.new(source: source, unit_price: nil, priced_unit: nil, cost: nil, status: :uncertain, reason: reason)
    end

    def latest_priced_observation(product)
      product.price_observations.with_standard_unit_price.order(observed_at: :desc, id: :desc).first
    end

    # The line's amount expressed in the product's priced unit, or nil when we
    # can't convert it without guessing. A plain in-dimension conversion is
    # tried first; failing that, the only cross-dimension move allowed is
    # count↔weight, and only when the product supplies an average weight per
    # unit to bridge the two.
    def quantity_in_priced_unit(source, product, priced_unit)
      quantity = source.quantity
      line_unit = source.unit

      direct = Measurement::Units.convert(quantity, from: line_unit, to: priced_unit)
      return direct if direct

      grams_per_each = product.each_weight_in_grams
      return if grams_per_each.blank? || grams_per_each.zero?

      line_dimension = Measurement::Units.dimension(line_unit)
      priced_dimension = Measurement::Units.dimension(priced_unit)

      if line_dimension == Measurement::Units::COUNT && priced_dimension == Measurement::Units::WEIGHT
        eaches = Measurement::Units.convert(quantity, from: line_unit, to: "each")
        grams = eaches * grams_per_each
        Measurement::Units.convert(grams, from: "g", to: priced_unit)
      elsif line_dimension == Measurement::Units::WEIGHT && priced_dimension == Measurement::Units::COUNT
        grams = Measurement::Units.to_base(quantity, line_unit)
        eaches = grams / grams_per_each
        Measurement::Units.convert(eaches, from: "each", to: priced_unit)
      end
    end

    # A plain-language reason a line couldn't be converted, tailored so the fix
    # is obvious: an unrecognised unit, a count↔weight gap that an average weight
    # would close, or genuinely incompatible dimensions.
    def conversion_reason(line_unit, priced_unit, product)
      line_dimension = Measurement::Units.dimension(line_unit)
      priced_dimension = Measurement::Units.dimension(priced_unit)

      if line_dimension.nil?
        %(Recipe unit "#{line_unit}" isn't one we can convert — left uncertain rather than guessed)
      elsif priced_dimension.nil?
        %(The priced unit "#{priced_unit}" isn't one we can convert — left uncertain rather than guessed)
      elsif count_and_weight?(line_dimension, priced_dimension)
        %(#{product.canonical_name} is priced by #{priced_unit} but the recipe uses #{line_unit}; set an average weight per unit on the product to bridge count and weight)
      else
        %(Recipe unit "#{line_unit}" and the priced unit "#{priced_unit}" measure different things, so no conversion is assumed)
      end
    end

    def count_and_weight?(first_dimension, second_dimension)
      [ first_dimension, second_dimension ].sort == [ Measurement::Units::COUNT, Measurement::Units::WEIGHT ].sort
    end
  end
end
