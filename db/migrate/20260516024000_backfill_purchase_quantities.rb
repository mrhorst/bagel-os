class BackfillPurchaseQuantities < ActiveRecord::Migration[8.1]
  class ReceiptLineItemRecord < ActiveRecord::Base
    self.table_name = "receipt_line_items"
  end

  class PriceObservationRecord < ActiveRecord::Base
    self.table_name = "price_observations"
  end

  def up
    ReceiptLineItemRecord.find_each do |line_item|
      unit_quantity = decimal(line_item.raw_quantity)
      case_quantity = decimal(line_item.raw_case_quantity)
      purchase_kind = purchase_kind_for(unit_quantity, case_quantity)
      quantity = quantity_for(purchase_kind, unit_quantity, case_quantity)

      line_attributes = {
        unit_quantity: unit_quantity,
        case_quantity: case_quantity,
        quantity: quantity
      }

      line_attributes[:package_price] = nil if purchase_kind == "mixed"
      line_item.update_columns(line_attributes)

      PriceObservationRecord.where(receipt_line_item_id: line_item.id).find_each do |observation|
        observation_attributes = {
          unit_quantity: unit_quantity,
          case_quantity: case_quantity,
          purchase_kind: purchase_kind,
          quantity: quantity,
          presentation_key: presentation_key_for(observation.presentation_key, purchase_kind),
          presentation_label: presentation_label_for(observation.presentation_label, purchase_kind)
        }

        if purchase_kind == "mixed"
          observation_attributes.merge!(
            package_price: nil,
            unit_price: nil,
            standard_quantity: nil,
            standard_unit_price: nil,
            standard_unit: nil,
            needs_unit_review: true,
            price_basis: "presentation"
          )
        end

        observation.update_columns(observation_attributes)
      end
    end
  end

  def down
    ReceiptLineItemRecord.update_all(unit_quantity: nil, case_quantity: nil)
    PriceObservationRecord.update_all(unit_quantity: nil, case_quantity: nil, purchase_kind: nil)
  end

  private

  def decimal(value)
    return BigDecimal("0") if value.blank?

    BigDecimal(value.to_s)
  rescue ArgumentError
    BigDecimal("0")
  end

  def purchase_kind_for(unit_quantity, case_quantity)
    unit_present = unit_quantity.positive?
    case_present = case_quantity.positive?

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

  def presentation_key_for(existing_key, purchase_kind)
    return existing_key if existing_key.to_s.start_with?("#{purchase_kind}|")

    [ purchase_kind, existing_key ].compact_blank.join("|")
  end

  def presentation_label_for(existing_label, purchase_kind)
    return existing_label if existing_label.to_s.split(" · ").include?(purchase_kind)

    [ existing_label, purchase_kind ].compact_blank.join(" · ")
  end
end
