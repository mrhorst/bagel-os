require "digest"

module Purchasing
  class ReceiptLineNormalizer
    ReviewIntent = Struct.new(:issue_type, :description, keyword_init: true)

    class Result
      attr_reader :line_data, :parsed_unit, :case_pack, :calculated, :existing_raw_data, :product

      def initialize(line_data:, parsed_unit:, case_pack:, calculated:, existing_raw_data:, product:)
        @line_data = line_data
        @parsed_unit = parsed_unit
        @case_pack = case_pack
        @calculated = calculated
        @existing_raw_data = existing_raw_data || {}
        @product = product
      end

      def line_item_attributes
        {
          line_number: line_data[:line_number],
          line_type: line_data[:line_type],
          raw_name: line_data[:raw_name],
          raw_sku: line_data[:raw_sku],
          raw_quantity: line_data[:raw_quantity],
          raw_case_quantity: line_data[:raw_case_quantity],
          raw_package_description: line_data[:raw_name],
          line_total: line_data[:line_total],
          row_checksum: Digest::SHA256.hexdigest(line_data[:raw_data].to_json)
        }.merge(normalized_attributes)
      end

      def normalized_attributes
        {
          raw_unit: parsed_unit.unit_of_measure,
          unit_quantity: calculated[:unit_quantity],
          case_quantity: calculated[:case_quantity],
          quantity: calculated[:quantity],
          case_pack: case_pack,
          inner_quantity: calculated[:inner_quantity],
          inner_unit_price: calculated[:inner_unit_price],
          inner_unit_label: calculated[:inner_unit_label],
          package_price: calculated[:package_price],
          line_total: line_data[:line_total],
          parsed_package_size: parsed_unit.package_size,
          parsed_unit_of_measure: parsed_unit.unit_of_measure,
          confidence_score: parsed_unit.confidence || 0,
          needs_review: needs_review?,
          raw_data: normalized_raw_data
        }
      end

      def normalized_raw_data
        existing_raw_data.deep_stringify_keys
          .merge((line_data[:raw_data] || {}).deep_stringify_keys)
          .merge(
            "parsed_unit" => parsed_unit.to_h.deep_stringify_keys,
            "calculated" => calculated.deep_stringify_keys
          )
      end

      def needs_review?(product: self.product)
        line_data[:line_type] != "item" ||
          unit_parse_needs_review? ||
          mixed_quantity? ||
          price_needs_review? ||
          unknown_category?(product)
      end

      # Every reason needs_review? flags must emit a review intent, so the
      # invariant the rest of the system assumes — needs_review ⟺ a pending
      # review exists — holds. Otherwise a line flagged only by price (no
      # derivable comparable price) or only by being a non-item, non-coupon row
      # (e.g. an adjustment) gets needs_review: true with zero reviews, and the
      # edit page's resolve UI never appears: the flag is stuck forever (#172).
      def review_intents(product: self.product)
        intents = []
        intents << ReviewIntent.new(issue_type: "coupon", description: COUPON_REVIEW) if line_data[:line_type] == "coupon"
        intents << ReviewIntent.new(issue_type: "adjustment", description: ADJUSTMENT_REVIEW) if non_item_non_coupon?
        intents << ReviewIntent.new(issue_type: "unit_parse", description: parsed_unit.notes || UNIT_REVIEW) if unit_parse_needs_review?
        intents << ReviewIntent.new(issue_type: "mixed_quantity", description: MIXED_QUANTITY_REVIEW) if mixed_quantity?
        intents << ReviewIntent.new(issue_type: "missing_category", description: MISSING_CATEGORY_REVIEW) if unknown_category?(product)
        intents << ReviewIntent.new(issue_type: "case_pack", description: CASE_PACK_REVIEW) if case_pack_needs_review?
        intents << ReviewIntent.new(issue_type: "price", description: PRICE_REVIEW) if price_review_intent_needed?(product)
        intents
      end

      def review_intent?(issue_type, product: self.product)
        review_intents(product: product).any? { |intent| intent.issue_type == issue_type }
      end

      private

      def non_item_non_coupon?
        line_data[:line_type] != "item" && line_data[:line_type] != "coupon"
      end

      # A price flag only needs its own review when nothing more specific already
      # covers the line. Non-item rows are covered by the coupon/adjustment
      # intent; lines with a unit, mixed-quantity, category, or case-pack issue
      # already emit a structured intent. This is the catch-all so an item line
      # flagged purely for a missing comparable price still has something to
      # resolve, without doubling up reviews when another reason fired.
      def price_review_intent_needed?(product)
        return false unless price_needs_review?
        return false if line_data[:line_type] != "item"

        !(unit_parse_needs_review? || mixed_quantity? || unknown_category?(product) || case_pack_needs_review?)
      end

      def unknown_category?(product)
        product&.product_category&.name == "Other / unknown"
      end

      def case_pack_needs_review?
        line_data[:raw_case_quantity].to_d.positive? &&
          calculated[:inner_unit_price].blank? &&
          calculated[:standard_unit_price].blank? &&
          !mixed_quantity?
      end

      def unit_parse_needs_review?
        parsed_unit.needs_review && calculated[:case_pack_id].blank?
      end

      def price_needs_review?
        calculated[:standard_unit_price].blank? && calculated[:inner_unit_price].blank?
      end

      def mixed_quantity?
        calculated[:purchase_kind] == "mixed"
      end
    end

    COUPON_REVIEW = "Coupon/discount row imported for traceability but not mapped to a product price."
    ADJUSTMENT_REVIEW = "Non-item row (e.g. a fee or adjustment) imported for traceability but not mapped to a product price. Mark resolved once you've confirmed it, or ignore it."
    PRICE_REVIEW = "No comparable unit price could be derived for this line (e.g. a $0.00 or comp line). Mark resolved once you've confirmed it, or ignore it."
    UNIT_REVIEW = "Package size or unit needs review."
    MIXED_QUANTITY_REVIEW = "Both Unit Qty and Case Qty are present. Price is not allocated automatically between unit and case presentations."
    MISSING_CATEGORY_REVIEW = "Product category could not be classified confidently."
    CASE_PACK_REVIEW = "Case quantity is present, but case pack size/unit is not clear enough to calculate comparable unit price."

    def initialize(unit_parser: UnitParser.new, price_calculator: PriceCalculator.new, case_pack_resolver: CasePackResolver.new)
      @unit_parser = unit_parser
      @price_calculator = price_calculator
      @case_pack_resolver = case_pack_resolver
    end

    def normalize(line_data:, existing_raw_data: {}, product: nil)
      parsed_unit = unit_parser.parse(
        line_data[:raw_name],
        raw_quantity: line_data[:raw_quantity],
        raw_case_quantity: line_data[:raw_case_quantity]
      )
      case_pack = case_pack_resolver.resolve(line_data: line_data, product: product)
      calculated = price_calculator.calculate(line_data, parsed_unit, case_pack: case_pack)

      Result.new(
        line_data: line_data,
        parsed_unit: parsed_unit,
        case_pack: case_pack,
        calculated: calculated,
        existing_raw_data: existing_raw_data,
        product: product
      )
    end

    private

    attr_reader :unit_parser, :price_calculator, :case_pack_resolver
  end
end
