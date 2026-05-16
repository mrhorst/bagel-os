module Purchasing
  class InventoryGapAnalyzer
    NON_RECURRING_PATTERN = /
      APRON|BUS\ BOX|COFFEE\ POT|FUNNEL|GRAVY\ BOAT|MEASURING|PLATE\ RACK|
      SCOOP|SERVING\ TRAY|TOILET\ BRUSH|TOWEL\ BASKET|TRAY
    /ix

    Row = Struct.new(
      :product,
      :purchase_count,
      :total_spend,
      :last_purchased_at,
      :classification,
      :reason,
      keyword_init: true
    )

    def initialize(linking: OrderGuideLinking.new)
      @linking = linking
    end

    def missing_products(limit: nil)
      guide_product_ids = linking.covered_product_ids

      rows = Product
        .active
        .includes(:product_aliases, :product_category, :price_observations)
        .where.not(id: guide_product_ids)
        .select { |product| product.price_observations.any? && !linking.covered_by_guide_name?(product) }
        .map { |product| row_for(product) }
        .sort_by { |row| [ priority_for(row), -row.total_spend.to_d, row.product.canonical_name ] }

      limit ? rows.first(limit) : rows
    end

    def summary
      rows = missing_products
      {
        missing_count: rows.size,
        review_count: rows.count { |row| row.classification == "review_for_guide" },
        occasional_count: rows.count { |row| row.classification == "occasional_or_equipment" },
        one_off_count: rows.count { |row| row.classification == "one_off_or_low_signal" }
      }
    end

    private

    attr_reader :linking

    def row_for(product)
      observations = product.price_observations
      purchase_count = observations.size
      total_spend = observations.sum { |observation| observation.line_total.to_d }
      classification, reason = classify(product, purchase_count, total_spend)

      Row.new(
        product: product,
        purchase_count: purchase_count,
        total_spend: total_spend,
        last_purchased_at: observations.map(&:observed_at).max,
        classification: classification,
        reason: reason
      )
    end

    def classify(product, purchase_count, total_spend)
      name = product.canonical_name.to_s.upcase
      category = product.category_name

      if name.match?(NON_RECURRING_PATTERN) || category.in?([ "Smallwares", "Equipment / maintenance" ])
        [ "occasional_or_equipment", "Looks like occasional equipment/smallwares; keep off guide unless you want it reviewed every run." ]
      elsif purchase_count >= 2 || total_spend.to_d >= 50
        [ "review_for_guide", "Recurring enough in receipt history to review against the guide." ]
      else
        [ "one_off_or_low_signal", "Only one low-signal purchase so far; review later unless it is operationally important." ]
      end
    end

    def priority_for(row)
      case row.classification
      when "review_for_guide"
        0
      when "one_off_or_low_signal"
        1
      else
        2
      end
    end
  end
end
