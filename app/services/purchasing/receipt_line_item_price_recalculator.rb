module Purchasing
  class ReceiptLineItemPriceRecalculator
    def initialize(unit_parser: UnitParser.new, price_calculator: PriceCalculator.new, observation_builder: PriceObservationBuilder.new)
      @unit_parser = unit_parser
      @price_calculator = price_calculator
      @observation_builder = observation_builder
    end

    def recalculate_all!
      stats = { line_items_reviewed: 0, line_items_updated: 0, observations_rebuilt: 0 }

      PriceObservation.delete_all

      ReceiptLineItem.includes(:product, :receipt, :import_batch, :normalization_reviews).find_each do |line_item|
        stats[:line_items_reviewed] += 1
        parsed_unit = unit_parser.parse(
          line_item.raw_name,
          raw_quantity: line_item.raw_quantity,
          raw_case_quantity: line_item.raw_case_quantity
        )
        calculated = price_calculator.calculate(line_data_for(line_item), parsed_unit)

        update_line_item!(line_item, parsed_unit, calculated)
        sync_unit_reviews!(line_item, parsed_unit, calculated)
        stats[:line_items_updated] += 1

        observation = observation_builder.create_for!(line_item)
        stats[:observations_rebuilt] += 1 if observation
      end

      PriceSpikeFlagger.new.flag_all!
      stats.merge(price_observations_total: PriceObservation.count)
    end

    private

    attr_reader :unit_parser, :price_calculator, :observation_builder

    def line_data_for(line_item)
      {
        line_type: line_item.line_type,
        raw_quantity: line_item.raw_quantity,
        raw_case_quantity: line_item.raw_case_quantity,
        line_total: line_item.line_total
      }
    end

    def update_line_item!(line_item, parsed_unit, calculated)
      line_item.update!(
        raw_unit: parsed_unit.unit_of_measure,
        quantity: calculated[:quantity],
        package_price: calculated[:package_price],
        parsed_package_size: parsed_unit.package_size,
        parsed_unit_of_measure: parsed_unit.unit_of_measure,
        confidence_score: parsed_unit.confidence || 0,
        needs_review: line_item_needs_review?(line_item, parsed_unit, calculated),
        raw_data: line_item.raw_data.merge(
          "parsed_unit" => parsed_unit.to_h,
          "calculated" => calculated
        )
      )
    end

    def line_item_needs_review?(line_item, parsed_unit, calculated)
      line_item.line_type != "item" ||
        parsed_unit.needs_review ||
        calculated[:standard_unit_price].blank? ||
        line_item.product&.product_category&.name == "Other / unknown"
    end

    def sync_unit_reviews!(line_item, parsed_unit, calculated)
      if parsed_unit.needs_review
        create_review!(line_item, "unit_parse", parsed_unit.notes || "Package size or unit needs review.")
      else
        resolve_reviews!(line_item, "unit_parse", "Resolved after package size and unit were parsed clearly.")
      end

      if line_item.raw_case_quantity.to_d.positive? && calculated[:standard_unit_price].blank?
        create_review!(line_item, "case_pack", "Case quantity is present, but case pack size/unit is not clear enough to calculate comparable unit price.")
      else
        resolve_reviews!(line_item, "case_pack", "Resolved after case quantity was paired with an explicit package size and unit.")
      end
    end

    def create_review!(line_item, issue_type, description)
      line_item.normalization_reviews.find_or_create_by!(issue_type: issue_type, status: "pending") do |review|
        review.product = line_item.product
        review.description = description
      end
    end

    def resolve_reviews!(line_item, issue_type, note)
      line_item.normalization_reviews.pending.where(issue_type: issue_type).find_each do |review|
        review.update!(status: "resolved", resolution_notes: note)
      end
    end
  end
end
