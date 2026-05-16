module Purchasing
  class PriceCalculator
    def calculate(line_data, parsed_unit, case_pack: nil)
      unit_quantity = decimal(line_data[:raw_quantity])
      case_quantity = decimal(line_data[:raw_case_quantity])
      purchase_kind = purchase_kind_for(unit_quantity, case_quantity)
      quantity = quantity_for(purchase_kind, unit_quantity, case_quantity)
      line_total = line_data[:line_total]
      package_price = divide(line_total, quantity)
      standard_unit_price = nil
      standard_quantity = nil
      inner_quantity = nil
      inner_unit_price = nil

      if case_pack_usable?(case_pack, purchase_kind, line_total, case_quantity)
        inner_quantity = case_pack.inner_quantity_for(case_quantity: case_quantity)
        inner_unit_price = case_pack.inner_unit_price_for(line_total: line_total, case_quantity: case_quantity)
        standard_quantity = case_pack.standard_quantity_for(case_quantity: case_quantity)
        standard_unit_price = divide(line_total, standard_quantity)
      elsif standardizable?(line_data, parsed_unit, quantity, line_total, purchase_kind)
        standard_quantity = quantity * parsed_unit.package_size
        standard_unit_price = divide(line_total, standard_quantity)
      end

      {
        unit_quantity: unit_quantity,
        case_quantity: case_quantity,
        quantity: quantity,
        purchase_kind: purchase_kind,
        case_pack_id: case_pack&.id,
        inner_quantity: inner_quantity,
        inner_unit_price: inner_unit_price,
        inner_unit_label: case_pack&.inner_unit_label,
        package_price: package_price,
        unit_price: package_price,
        standard_quantity: standard_quantity,
        standard_unit_price: standard_unit_price,
        standard_unit: standard_unit_price.present? ? standard_unit_for(parsed_unit, case_pack) : nil,
        price_basis: price_basis_for(standard_unit_price, inner_unit_price)
      }
    end

    private

    def purchase_kind_for(unit_quantity, case_quantity)
      unit_present = unit_quantity&.positive?
      case_present = case_quantity&.positive?

      return "mixed" if unit_present && case_present
      return "unit" if unit_present
      return "case" if case_present

      "unknown"
    end

    def quantity_for(purchase_kind, unit_quantity, case_quantity)
      case purchase_kind
      when "unit"
        unit_quantity
      when "case"
        case_quantity
      end
    end

    def standardizable?(line_data, parsed_unit, quantity, line_total, purchase_kind)
      line_data[:line_type] == "item" &&
        %w[unit case].include?(purchase_kind) &&
        line_total&.positive? &&
        quantity&.positive? &&
        parsed_unit.package_size&.positive? &&
        parsed_unit.standard_unit.present? &&
        parsed_unit.confidence.to_d >= BigDecimal("0.9")
    end

    def case_pack_usable?(case_pack, purchase_kind, line_total, case_quantity)
      case_pack.present? &&
        purchase_kind == "case" &&
        line_total&.positive? &&
        case_quantity&.positive?
    end

    def standard_unit_for(parsed_unit, case_pack)
      case_pack&.standard_unit.presence || parsed_unit.standard_unit
    end

    def price_basis_for(standard_unit_price, inner_unit_price)
      return "standard_unit" if standard_unit_price.present?
      return "inner_unit" if inner_unit_price.present?

      "presentation"
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
