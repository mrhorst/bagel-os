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

    def missing_products(limit: nil)
      guide_product_ids = covered_product_ids

      rows = Product
        .active
        .includes(:product_aliases, :product_category, :price_observations)
        .where.not(id: guide_product_ids)
        .select { |product| product.price_observations.any? && !covered_by_guide_name?(product) }
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

    def covered_by_guide_name?(product)
      active_guide_items.any? do |guide_item|
        normalized_product_names(product).include?(matcher.normalize(guide_item.item_name))
      end
    end

    def normalized_product_names(product)
      [
        matcher.normalize(product.canonical_name),
        *product.product_aliases.map { |product_alias| matcher.normalize(product_alias.raw_name) }
      ].uniq
    end

    def active_guide_items
      @active_guide_items ||= OrderGuideItem.active.to_a
    end

    def covered_product_ids
      linked_ids = InventoryItem.active.where.not(product_id: nil).pluck(:product_id)
      matched_ids = active_guide_items.filter_map do |guide_item|
        matcher.match(
          guide_item.item_name,
          context: {
            section_name: guide_item.section_name,
            subcategory: guide_item.subcategory
          }
        ).product&.id
      end

      (linked_ids + matched_ids).uniq
    end

    def matcher
      @matcher ||= ProductNameMatcher.new
    end

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
