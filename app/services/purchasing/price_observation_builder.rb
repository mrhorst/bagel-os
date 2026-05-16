module Purchasing
  class PriceObservationBuilder
    def create_for!(line_item)
      return unless line_item.product
      return if line_item.line_type != "item"

      observation = PriceObservation.find_or_initialize_by(receipt_line_item: line_item)
      standard_unit_price = standard_unit_price_for(line_item)
      observation.assign_attributes(
        product: line_item.product,
        supplier: line_item.supplier,
        case_pack: line_item.case_pack,
        observed_at: line_item.receipt.purchased_at || line_item.import_batch.imported_at,
        package_price: line_item.package_price,
        unit_quantity: line_item.unit_quantity,
        case_quantity: line_item.case_quantity,
        purchase_kind: purchase_kind_for(line_item),
        inner_quantity: line_item.inner_quantity,
        inner_unit_price: line_item.inner_unit_price,
        inner_unit_label: line_item.inner_unit_label,
        quantity: line_item.quantity,
        line_total: line_item.line_total,
        unit_price: line_item.package_price,
        standard_quantity: standard_quantity_for(line_item),
        standard_unit_price: standard_unit_price,
        standard_unit: standard_unit_price.present? ? standard_unit_for(line_item) : nil,
        package_size: line_item.parsed_package_size,
        unit_of_measure: line_item.parsed_unit_of_measure,
        presentation_key: presentation_key_for(line_item),
        presentation_label: presentation_label_for(line_item),
        unit_confidence: unit_confidence_for(line_item),
        price_basis: standard_unit_price.present? ? "standard_unit" : "presentation",
        needs_unit_review: standard_unit_price.blank?,
        source_filename: line_item.import_batch.source_filename,
        notes: nil
      )
      observation.save!
      observation
    end

    private

    def standard_unit_price_for(line_item)
      return unless standard_unit_for(line_item).present?

      line_item.raw_data.dig("calculated", "standard_unit_price") || line_item.raw_data.dig(:calculated, :standard_unit_price)
    end

    def standard_quantity_for(line_item)
      line_item.raw_data.dig("calculated", "standard_quantity") || line_item.raw_data.dig(:calculated, :standard_quantity)
    end

    def standard_unit_for(line_item)
      line_item.raw_data.dig("calculated", "standard_unit") ||
        line_item.raw_data.dig(:calculated, :standard_unit) ||
        line_item.raw_data.dig("parsed_unit", "standard_unit") ||
        line_item.raw_data.dig(:parsed_unit, :standard_unit) ||
        line_item.product&.standard_unit
    end

    def unit_confidence_for(line_item)
      line_item.raw_data.dig("parsed_unit", "confidence") || line_item.raw_data.dig(:parsed_unit, :confidence)
    end

    def presentation_key_for(line_item)
      [
        purchase_kind_for(line_item),
        line_item.raw_sku.presence || "no-sku",
        normalize_key_part(line_item.raw_name),
        line_item.parsed_package_size&.to_d&.to_s("F"),
        line_item.parsed_unit_of_measure
      ].compact_blank.join("|")
    end

    def presentation_label_for(line_item)
      package = [
        compact_decimal(line_item.parsed_package_size),
        line_item.parsed_unit_of_measure
      ].compact_blank.join(" ")
      sku = line_item.raw_sku.present? ? "SKU #{line_item.raw_sku}" : "no SKU"
      kind = purchase_kind_for(line_item).presence

      [ line_item.raw_name, kind, sku, package.presence ].compact_blank.join(" · ")
    end

    def compact_decimal(value)
      return if value.blank?

      value.to_d.to_s("F").sub(/\.?0+\z/, "")
    end

    def normalize_key_part(value)
      value.to_s.upcase.scan(/[A-Z0-9]+/).join(" ")
    end

    def purchase_kind_for(line_item)
      line_item.raw_data.dig("calculated", "purchase_kind") ||
        line_item.raw_data.dig(:calculated, :purchase_kind) ||
        inferred_purchase_kind_for(line_item)
    end

    def inferred_purchase_kind_for(line_item)
      line_item.purchase_kind
    end
  end
end
