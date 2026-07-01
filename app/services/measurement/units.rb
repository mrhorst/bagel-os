module Measurement
  # A small, conservative unit system. Every unit belongs to a dimension
  # (weight, volume, or count) and converts only WITHIN its dimension, via a
  # factor to that dimension's base unit (grams, millilitres, each).
  #
  # Cross-dimension conversion is never guessed: turning "2 cups" into pounds, or
  # counting eggs by weight, depends on a product-specific fact (density, average
  # weight per each) that a generic table can't know. Callers that need such a
  # bridge must supply it explicitly; here, mismatched dimensions simply return
  # nil so the caller can leave the value uncertain rather than invent a number.
  #
  # Free-text unit labels ("lbs", "Tbsp.", "fl oz") are normalised to a canonical
  # key before any lookup. Anything we don't recognise stays unknown — it is
  # never coerced into a neighbouring unit.
  module Units
    WEIGHT = :weight
    VOLUME = :volume
    COUNT = :count

    # The base unit each dimension is measured in.
    BASE_UNITS = { WEIGHT => "g", VOLUME => "ml", COUNT => "each" }.freeze

    # canonical key => [dimension, factor to the dimension's base unit]
    CANONICAL = {
      # weight — base gram
      "mg" => [WEIGHT, BigDecimal("0.001")],
      "g" => [WEIGHT, BigDecimal("1")],
      "kg" => [WEIGHT, BigDecimal("1000")],
      "oz" => [WEIGHT, BigDecimal("28.349523125")],
      "lb" => [WEIGHT, BigDecimal("453.59237")],
      # volume — base millilitre
      "ml" => [VOLUME, BigDecimal("1")],
      "l" => [VOLUME, BigDecimal("1000")],
      "tsp" => [VOLUME, BigDecimal("4.92892159375")],
      "tbsp" => [VOLUME, BigDecimal("14.78676478125")],
      "fl_oz" => [VOLUME, BigDecimal("29.5735295625")],
      "cup" => [VOLUME, BigDecimal("236.5882365")],
      "pt" => [VOLUME, BigDecimal("473.176473")],
      "qt" => [VOLUME, BigDecimal("946.352946")],
      "gal" => [VOLUME, BigDecimal("3785.411784")],
      # count — base each
      "each" => [COUNT, BigDecimal("1")],
      "dozen" => [COUNT, BigDecimal("12")]
    }.freeze

    # Common free-text spellings => canonical key. Trailing plural "s" is handled
    # separately in #canonical, so most singular spellings are enough here.
    ALIASES = {
      "milligram" => "mg", "mgs" => "mg",
      "gram" => "g", "gr" => "g", "gm" => "g", "gms" => "g",
      "kilogram" => "kg", "kilo" => "kg", "kilos" => "kg", "kgs" => "kg",
      "ounce" => "oz", "ozs" => "oz",
      "pound" => "lb", "lbs" => "lb", "#" => "lb",
      "milliliter" => "ml", "millilitre" => "ml", "mls" => "ml", "cc" => "ml",
      "liter" => "l", "litre" => "l", "ltr" => "l",
      "teaspoon" => "tsp", "tsps" => "tsp",
      "tablespoon" => "tbsp", "tbsps" => "tbsp", "tbs" => "tbsp",
      "fluid ounce" => "fl_oz", "floz" => "fl_oz", "fl oz" => "fl_oz",
      "c" => "cup",
      "pint" => "pt", "pts" => "pt",
      "quart" => "qt", "qts" => "qt",
      "gallon" => "gal", "gals" => "gal",
      "ea" => "each", "unit" => "each", "ct" => "each", "count" => "each",
      "piece" => "each", "pc" => "each", "pcs" => "each", "qty" => "each", "ea." => "each",
      "doz" => "dozen", "dz" => "dozen"
    }.freeze

    module_function

    # The canonical key for a free-text unit, or nil when we don't recognise it.
    def canonical(unit)
      key = normalize(unit)
      return if key.blank?
      return key if CANONICAL.key?(key)
      return ALIASES[key] if ALIASES.key?(key)

      # Tolerate a trailing plural "s" ("cups" -> "cup", "ounces" -> ... via the
      # alias "ounce"). We try the singular against both tables.
      singular = key.chomp("s")
      return singular if CANONICAL.key?(singular)

      ALIASES[singular]
    end

    # The dimension (:weight/:volume/:count) of a unit, or nil if unknown.
    def dimension(unit)
      key = canonical(unit)
      CANONICAL[key]&.first
    end

    def known?(unit)
      canonical(unit).present?
    end

    def same_dimension?(first_unit, second_unit)
      dim = dimension(first_unit)
      dim.present? && dim == dimension(second_unit)
    end

    # Convert a quantity from one unit to another within the same dimension.
    # Returns nil when either unit is unknown or the two belong to different
    # dimensions — we never invent a cross-dimension factor.
    def convert(quantity, from:, to:)
      return if quantity.blank?

      from_key = canonical(from)
      to_key = canonical(to)
      return if from_key.nil? || to_key.nil?

      from_dimension, from_factor = CANONICAL[from_key]
      to_dimension, to_factor = CANONICAL[to_key]
      return unless from_dimension == to_dimension

      quantity.to_d * from_factor / to_factor
    end

    # A quantity expressed in its dimension's base unit (g / ml / each), or nil
    # when the unit is unknown.
    def to_base(quantity, unit)
      key = canonical(unit)
      return if key.nil? || quantity.blank?

      quantity.to_d * CANONICAL[key].last
    end

    def normalize(unit)
      unit.to_s.strip.downcase.delete(".").squeeze(" ")
    end
  end
end
