module Purchasing
  class UnitParser
    ParsedUnit = Struct.new(
      :package_size,
      :unit_of_measure,
      :standard_unit,
      :confidence,
      :notes,
      :needs_review,
      keyword_init: true
    )

    PATTERNS = [
      [ /(?<![#\d.\/-])(?<size>\d+(?:\.\d+)?)\s*(?:LB|LBS)\b/i, "lb" ],
      [ /(?<![#\d.\/-])(?<size>\d+(?:\.\d+)?)\s*#/i, "lb" ],
      [ /(?<![\d.\/-])(?<size>\d+(?:\.\d+)?)\s*(?:OZ|Z)\b/i, "oz" ],
      [ /(?<![\d.\/-])(?<size>\d+(?:\.\d+)?)\s*(?:GAL|GALLON)\b/i, "gallon" ],
      [ /(?<![\d.\/-])(?<size>\d+(?:\.\d+)?)\s*(?:QT|QRT|QUART)\b/i, "quart" ],
      [ /(?<![\d.\/-])(?<size>\d+(?:\.\d+)?)\s*(?:PT|PINT)\b/i, "pint" ],
      [ /(?<![\d.\/-])(?<size>\d+(?:\.\d+)?)\s*(?:LTR|LITER|L)\b/i, "liter" ],
      [ /(?<![\d.\/-])(?<size>\d+(?:\.\d+)?)\s*DZ\b/i, "dozen" ],
      [ /(?<![\d.\/-])(?<size>\d+(?:\.\d+)?)\s*CT\b/i, "count" ],
      [ /(?<![\d.\/-])(?<size>\d+(?:\.\d+)?)\s*ROLL\b/i, "roll" ],
      [ /(?<![\d.\/-])(?<size>\d+(?:\.\d+)?)\s*SHEET\b/i, "sheet" ]
    ].freeze

    AMBIGUOUS_PACK_RE = %r{\d+\s*[/-]\s*\d+(?:\.\d+)?\s*(?:OZ|Z|LB|LBS|GAL|QT|QRT|PT|CT|DZ)\b}i

    def parse(description, raw_quantity: nil, raw_case_quantity: nil)
      description = description.to_s
      unit_quantity = decimal(raw_quantity)
      case_quantity = decimal(raw_case_quantity)

      if description.match?(AMBIGUOUS_PACK_RE)
        return ParsedUnit.new(
          confidence: 0.5,
          notes: "Description appears to contain a multi-pack expression that needs human review.",
          needs_review: true
        )
      end

      PATTERNS.each do |pattern, unit|
        match = description.match(pattern)
        next unless match

        package_size = BigDecimal(match[:size])
        case_quantity_present = case_quantity&.positive?
        likely_total_package = !case_quantity_present || case_package_likely_total?(package_size, unit)

        return ParsedUnit.new(
          package_size: package_size,
          unit_of_measure: unit,
          standard_unit: unit,
          confidence: likely_total_package ? (case_quantity_present ? 0.9 : 0.95) : 0.65,
          notes: case_quantity_note(case_quantity_present, likely_total_package),
          needs_review: !likely_total_package
        )
      end

      if case_quantity&.positive?
        return ParsedUnit.new(
          confidence: 0.45,
          notes: "Case quantity is present, but receipt text does not expose a reliable package size and unit.",
          needs_review: true
        )
      end

      if description.match?(/\bR\/W\b/i) || unit_quantity.to_s.include?(".")
        return ParsedUnit.new(
          unit_of_measure: "raw_quantity",
          standard_unit: nil,
          confidence: 0.65,
          notes: "Random-weight or decimal quantity row. Keep calculated raw unit price, but do not assume a standard unit.",
          needs_review: true
        )
      end

      ParsedUnit.new(
        confidence: 0.35,
        notes: "No reliable package size or unit found in description.",
        needs_review: true
      )
    end

    private

    def decimal(value)
      return if value.blank?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    def case_package_likely_total?(package_size, unit)
      case unit
      when "lb"
        package_size >= 5
      when "oz"
        package_size >= 160
      when "dozen"
        package_size >= 1
      when "count", "sheet"
        package_size >= 100
      else
        false
      end
    end

    def case_quantity_note(case_quantity_present, likely_total_package)
      return unless case_quantity_present

      if likely_total_package
        "Case quantity is present, and the visible package size looks like the full purchased presentation."
      else
        "Case quantity is present, but the visible package size may be an inner pack rather than the full case."
      end
    end
  end
end
