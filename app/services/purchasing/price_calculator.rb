module Purchasing
  class PriceCalculator
    def calculate(line_data, parsed_unit)
      quantity = quantity_for(line_data)
      line_total = line_data[:line_total]
      package_price = divide(line_total, quantity)
      standard_unit_price = nil
      standard_quantity = nil

      if standardizable?(line_data, parsed_unit, quantity, line_total)
        standard_quantity = quantity * parsed_unit.package_size
        standard_unit_price = divide(line_total, standard_quantity)
      end

      {
        quantity: quantity,
        package_price: package_price,
        unit_price: package_price,
        standard_quantity: standard_quantity,
        standard_unit_price: standard_unit_price,
        standard_unit: standard_unit_price.present? ? parsed_unit.standard_unit : nil,
        price_basis: standard_unit_price.present? ? "standard_unit" : "presentation"
      }
    end

    private

    def quantity_for(line_data)
      unit_quantity = decimal(line_data[:raw_quantity])
      case_quantity = decimal(line_data[:raw_case_quantity])

      if unit_quantity&.positive?
        unit_quantity
      elsif case_quantity&.positive?
        case_quantity
      end
    end

    def standardizable?(line_data, parsed_unit, quantity, line_total)
      line_data[:line_type] == "item" &&
        line_total&.positive? &&
        quantity&.positive? &&
        parsed_unit.package_size&.positive? &&
        parsed_unit.standard_unit.present? &&
        parsed_unit.confidence.to_d >= BigDecimal("0.9")
    end

    def divide(amount, divisor)
      return unless amount && divisor&.positive?

      (amount / divisor).round(4)
    end

    def decimal(value)
      return BigDecimal("0") if value.blank?

      BigDecimal(value.to_s)
    rescue ArgumentError
      BigDecimal("0")
    end
  end
end
